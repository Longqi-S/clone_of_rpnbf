function save_model_path = fast_rcnn_train_widerface_ablation_mpfvn_cxt2(conf, imdb_train, roidb_train, varargin)
% save_model_path = fast_rcnn_train(conf, imdb_train, roidb_train, varargin)
% --------------------------------------------------------
% Fast R-CNN
% Reimplementation based on Python Fast R-CNN (https://github.com/rbgirshick/fast-rcnn)
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

%% inputs
    ip = inputParser;
    ip.addRequired('conf',                              @isstruct);
    ip.addRequired('imdb_train',                        @iscell);
    ip.addRequired('roidb_train',                       @iscell);
    ip.addParamValue('do_val',          true,          @isscalar);
    ip.addParamValue('imdb_val',        struct(),       @isstruct);
    ip.addParamValue('roidb_val',       struct(),       @isstruct);
    ip.addParamValue('val_iters',       500,            @isscalar); %500
    ip.addParamValue('val_interval',    1000,           @isscalar); %2000
    ip.addParamValue('snapshot_interval',...
                                        1000,          @isscalar); %2000
    ip.addParamValue('solver_def_file', fullfile(pwd, 'models', 'Zeiler_conv5', 'solver.prototxt'), ...
                                                        @isstr);
    ip.addParamValue('net_file',        fullfile(pwd, 'models', 'Zeiler_conv5', 'Zeiler_conv5'), ...
                                                        @isstr);
    ip.addParamValue('exp_name',          'tmp', ...
                                                        @isstr);
    ip.addParamValue('cache_name',      'Zeiler_conv5', ...
                                                        @isstr);
    
    ip.parse(conf, imdb_train, roidb_train, varargin{:});
    opts = ip.Results;
    
%% try to find trained model
    imdbs_name = cell2mat(cellfun(@(x) x.name, imdb_train, 'UniformOutput', false));
	cache_dir = fullfile(pwd, 'output', opts.exp_name, 'fast_rcnn_cachedir', opts.cache_name, imdbs_name);   
	%cache_dir = fullfile(pwd, 'output', 'fast_rcnn_cachedir', opts.cache_name, imdbs_name);
	mkdir_if_missing(cache_dir);
	save_model_path = fullfile(cache_dir, 'final');
    if exist(save_model_path, 'file')
        return;
    end
    
%% init
    % init caffe solver
    %mkdir_if_missing(cache_dir);
    caffe_log_file_base = fullfile(cache_dir, 'caffe_log');
    caffe.init_log(caffe_log_file_base);
    caffe_solver = caffe.Solver(opts.solver_def_file);
    %0306 training from iter_14000-> the last ok iteration
    caffe_solver.net.copy_from(opts.net_file);
    %caffe_solver.net.copy_from(fullfile(pwd, 'output','VGG16_widerface_multibox_ablation_final_fastrcnn','fast_rcnn_cachedir',...
    %                                         'rpn_widerface_VGG16_stage1_fast_rcnn','WIDERFACE_train', 'iter_14000_puck'));

    % init log
    timestamp = datestr(datevec(now()), 'yyyymmdd_HHMMSS');
    mkdir_if_missing(fullfile(cache_dir, 'log'));
    log_file = fullfile(cache_dir, 'log', ['train_', timestamp, '.txt']);
    diary(log_file);
    
    % set random seed
    prev_rng = seed_rand(conf.rng_seed);
    caffe.set_random_seed(conf.rng_seed);
    
    % set gpu/cpu
    if conf.use_gpu
        caffe.set_mode_gpu();
    else
        caffe.set_mode_cpu();
    end
    
    disp('conf:');
    disp(conf);
    disp('opts:');
    disp(opts);
    
%% making tran/val data
    fprintf('Preparing training data...');
    train_roi_name = fullfile(cache_dir, 'train_fastrcnn_roidb_all.mat');
    test_roi_name = fullfile(cache_dir, 'test_fastrcnn_roidb_all.mat');
    try 
        load(train_roi_name);
    catch
        [image_roidb_train, bbox_means, bbox_stds]...
                            = fast_rcnn_prepare_image_roidb(conf, opts.imdb_train, opts.roidb_train);
        save(train_roi_name, 'image_roidb_train', 'bbox_means', 'bbox_stds','-v7.3');
    end
    fprintf('Done.\n');
    
    if opts.do_val
        fprintf('Preparing validation data...');
        try
            load(test_roi_name);
        catch
            [image_roidb_val]...
                                = fast_rcnn_prepare_image_roidb(conf, opts.imdb_val, opts.roidb_val, bbox_means, bbox_stds);
            save(test_roi_name, 'image_roidb_val','-v7.3');                
        end
        fprintf('Done.\n');

        % fix validation data
        shuffled_inds_val = generate_random_minibatch([], image_roidb_val, conf.ims_per_batch);
        shuffled_inds_val = shuffled_inds_val(randperm(length(shuffled_inds_val), opts.val_iters));
    end
    
%%  try to train/val with images which have maximum size potentially, to validate whether the gpu memory is enough  
    %1207 temperarily masked, open it when officially training
    %1208 reopen
    num_classes = size(image_roidb_train(1).overlap, 2);
    check_gpu_memory(conf, caffe_solver, num_classes, opts.do_val);
    
%% training
    shuffled_inds = [];
    train_results = [];  
    val_results = [];  
    iter_ = caffe_solver.iter();
    max_iter = caffe_solver.max_iter();
    
    % 0927 added to record plot info
    modelFigPath = fullfile(cache_dir, 'net-train.pdf');  % plot save path
    tmp_struct = struct('loss_bbox', [], 'loss_cls', [], 'accuracy', []);
    history_rec = struct('train',tmp_struct,'val',tmp_struct, 'num', 0);
    
    while (iter_ <= max_iter)
		% begin time counting
        start_time = tic;
        caffe_solver.net.set_phase('train');

        % generate minibatch training data
        [shuffled_inds, sub_db_inds] = generate_random_minibatch(shuffled_inds, image_roidb_train, conf.ims_per_batch);
        %[im_blob, rois_blob, labels_blob, bbox_targets_blob, bbox_loss_weights_blob] = ...
        %    fast_rcnn_get_minibatch_batch2(conf, image_roidb_train(sub_db_inds));
        [im_blob, rois_blob_s4, rois_cxt_blob_s4, rois_blob_s8, rois_cxt_blob_s8, rois_blob_s16, rois_cxt_blob_s16, labels_blob] = ...
            fast_rcnn_get_minibatch_mpfvn_cxt2(conf, image_roidb_train(sub_db_inds));

        %net_inputs = {im_blob, rois_blob, labels_blob, bbox_targets_blob, bbox_loss_weights_blob};
        net_inputs = {im_blob, rois_blob_s4, rois_cxt_blob_s4, rois_blob_s8, rois_cxt_blob_s8, rois_blob_s16, rois_cxt_blob_s16, labels_blob};
        caffe_solver.net.reshape_as_input(net_inputs);

        % one iter SGD update
        caffe_solver.net.set_input_data(net_inputs);
        caffe_solver.step(1);
		cost_time = toc(start_time);
        
        rst = caffe_solver.net.get_output();
		%1016 added then commented ==> fg-acc and bg-acc are only for rpn
        %rst = check_error(rst, caffe_solver);
        
        %format long
        fprintf('Iter %d, Image %d: %.1f Hz, ', iter_, sub_db_inds(1), 1/cost_time);
        for kkk = 1:length(rst)
            fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
        end
        fprintf('\n');
        
        train_results = parse_rst(train_results, rst);
            
        % do valdiation per val_interval iterations
        if ~mod(iter_, opts.val_interval) 
            if opts.do_val
                caffe_solver.net.set_phase('test');                
                for i = 1:length(shuffled_inds_val)
                    sub_db_inds = shuffled_inds_val{i};
                    %[im_blob, rois_blob, labels_blob, bbox_targets_blob, bbox_loss_weights_blob] = ...
                    %    fast_rcnn_get_minibatch_batch2(conf, image_roidb_val(sub_db_inds));
                    [im_blob, rois_blob_s4, rois_cxt_blob_s4, rois_blob_s8, rois_cxt_blob_s8, rois_blob_s16, rois_cxt_blob_s16, labels_blob] = ...
                        fast_rcnn_get_minibatch_mpfvn_cxt2(conf, image_roidb_val(sub_db_inds));

                    % Reshape net's input blobs
                    %net_inputs = {im_blob, rois_blob, labels_blob, bbox_targets_blob, bbox_loss_weights_blob};
                    net_inputs = {im_blob, rois_blob_s4, rois_cxt_blob_s4, rois_blob_s8, rois_cxt_blob_s8, rois_blob_s16, rois_cxt_blob_s16, labels_blob};
                    caffe_solver.net.reshape_as_input(net_inputs);
                    
                    caffe_solver.net.forward(net_inputs);
                    
                    rst = caffe_solver.net.get_output();
                    %0326 added for debug
%                     bb = caffe_solver.net.blobs('cls_score').get_data(); 
%                     bb = bb';
%                     if (~isempty(bb)) && any(bb(:,1) <= bb(:,2))
%                         fprintf('flip happens!!!\n');
%                     end
                    
                    val_results = parse_rst(val_results, rst);
                end
            end
            
            %show_state(iter_, train_results, val_results);modelFigPath
            history_rec = show_state(iter_, train_results, val_results, history_rec, modelFigPath);
            
            train_results = [];
            val_results = [];
            diary; diary; % flush diary
        end
        
        % snapshot
        if ~mod(iter_, opts.snapshot_interval)
            %snapshot(caffe_solver, bbox_means, bbox_stds, cache_dir, sprintf('iter_%d', iter_));
            snapshot(caffe_solver, cache_dir, sprintf('iter_%d', iter_));
        end
        
        iter_ = caffe_solver.iter();
    end
    
    % final snapshot ==> no need to do, already done in while loop
    %snapshot(caffe_solver, bbox_means, bbox_stds, cache_dir, sprintf('iter_%d', iter_));
    %save_model_path = snapshot(caffe_solver, bbox_means, bbox_stds, cache_dir, 'final');
    save_model_path = snapshot(caffe_solver, cache_dir, 'final');

    diary off;
    caffe.reset_all(); 
    rng(prev_rng);
end

function [shuffled_inds, sub_inds] = generate_random_minibatch(shuffled_inds, image_roidb_train, ims_per_batch)

    % shuffle training data per batch
    if isempty(shuffled_inds)
        % make sure each minibatch, only has horizontal images or vertical
        % images, to save gpu memory
        
        hori_image_inds = arrayfun(@(x) x.im_size(2) >= x.im_size(1), image_roidb_train, 'UniformOutput', true);
        vert_image_inds = ~hori_image_inds;
        hori_image_inds = find(hori_image_inds);
        vert_image_inds = find(vert_image_inds);
        
        % random perm
        lim = floor(length(hori_image_inds) / ims_per_batch) * ims_per_batch;
        hori_image_inds = hori_image_inds(randperm(length(hori_image_inds), lim));
        lim = floor(length(vert_image_inds) / ims_per_batch) * ims_per_batch;
        vert_image_inds = vert_image_inds(randperm(length(vert_image_inds), lim));
        
        % combine sample for each ims_per_batch 
        hori_image_inds = reshape(hori_image_inds, ims_per_batch, []);
        vert_image_inds = reshape(vert_image_inds, ims_per_batch, []);
        
        shuffled_inds = [hori_image_inds, vert_image_inds];
        shuffled_inds = shuffled_inds(:, randperm(size(shuffled_inds, 2)));
        
        shuffled_inds = num2cell(shuffled_inds, 1);
    end
    
    if nargout > 1
        % generate minibatch training data
        sub_inds = shuffled_inds{1};
        assert(length(sub_inds) == ims_per_batch);
        shuffled_inds(1) = [];
    end
end


function check_gpu_memory(conf, caffe_solver, num_classes, do_val)
%%  try to train/val with images which have maximum size potentially, to validate whether the gpu memory is enough  

    % generate pseudo training data with max size
    im_blob = single(zeros(max(conf.scales), conf.max_size, 3, conf.ims_per_batch));
    rois_blob_s4 = single(repmat([0; 0; 0; max(conf.scales)-1; conf.max_size-1], 1, conf.batch_size_s4));
    rois_blob_s4 = permute(rois_blob_s4, [3, 4, 1, 2]);
    %0322 added
    rois_blob_cxt_s4 = single(repmat([0; 0; 0; max(conf.scales)-1; conf.max_size-1], 1, conf.batch_size_s4));
    rois_blob_cxt_s4 = permute(rois_blob_cxt_s4, [3, 4, 1, 2]);
    
    rois_blob_s8 = single(repmat([0; 0; 0; max(conf.scales)-1; conf.max_size-1], 1, conf.batch_size_s8));
    rois_blob_s8 = permute(rois_blob_s8, [3, 4, 1, 2]);
    %0322 added
    rois_blob_cxt_s8 = single(repmat([0; 0; 0; max(conf.scales)-1; conf.max_size-1], 1, conf.batch_size_s8));
    rois_blob_cxt_s8 = permute(rois_blob_cxt_s8, [3, 4, 1, 2]);
    
    rois_blob_s16 = single(repmat([0; 0; 0; max(conf.scales)-1; conf.max_size-1], 1, conf.batch_size_s16));
    rois_blob_s16 = permute(rois_blob_s16, [3, 4, 1, 2]);
    %0322 added
    rois_blob_cxt_s16 = single(repmat([0; 0; 0; max(conf.scales)-1; conf.max_size-1], 1, conf.batch_size_s16));
    rois_blob_cxt_s16 = permute(rois_blob_cxt_s16, [3, 4, 1, 2]);
    
    labels_blob = single(ones(conf.batch_size_s4 + conf.batch_size_s8 + conf.batch_size_s16, 1));
    labels_blob = permute(labels_blob, [3, 4, 2, 1]);
    
    %0304 changed
    %net_inputs = {im_blob, rois_blob, labels_blob, bbox_targets_blob, bbox_loss_weights_blob};
    net_inputs = {im_blob, rois_blob_s4, rois_blob_cxt_s4, rois_blob_s8, rois_blob_cxt_s8, rois_blob_s16, rois_blob_cxt_s16, labels_blob};
    
    % Reshape net's input blobs
    caffe_solver.net.reshape_as_input(net_inputs);

    % one iter SGD update
    caffe_solver.net.set_input_data(net_inputs);
    caffe_solver.step(1);

    if do_val
        % use the same net with train to save memory
        caffe_solver.net.set_phase('test');
        caffe_solver.net.forward(net_inputs);
        caffe_solver.net.set_phase('train');
    end
end

%function model_path = snapshot(caffe_solver, bbox_means, bbox_stds, cache_dir, file_name)
function model_path = snapshot(caffe_solver, cache_dir, file_name)
%     bbox_stds_flatten = reshape(bbox_stds', [], 1);
%     bbox_means_flatten = reshape(bbox_means', [], 1);
%     
%     % merge bbox_means, bbox_stds into the model
%     bbox_pred_layer_name = 'bbox_pred';
%     weights = caffe_solver.net.params(bbox_pred_layer_name, 1).get_data();
%     biase = caffe_solver.net.params(bbox_pred_layer_name, 2).get_data();
%     weights_back = weights;
%     biase_back = biase;
%     
%     weights = ...
%         bsxfun(@times, weights, bbox_stds_flatten'); % weights = weights * stds; 
%     biase = ...
%         biase .* bbox_stds_flatten + bbox_means_flatten; % bias = bias * stds + means;
%     
%     caffe_solver.net.set_params_data(bbox_pred_layer_name, 1, weights);
%     caffe_solver.net.set_params_data(bbox_pred_layer_name, 2, biase);

    model_path = fullfile(cache_dir, file_name);
    caffe_solver.net.save(model_path);
    fprintf('Saved as %s\n', model_path);
    
%     % restore net to original state
%     caffe_solver.net.set_params_data(bbox_pred_layer_name, 1, weights_back);
%     caffe_solver.net.set_params_data(bbox_pred_layer_name, 2, biase_back);
end

function history_rec = show_state(iter, train_results, val_results, history_rec, modelFigPath)
    fprintf('\n------------------------- Iteration %d -------------------------\n', iter);
    fprintf('Training : error %.3g, loss (cls %.3g)\n', ...
        1 - mean(train_results.accuarcy.data), ...
        mean(train_results.loss_cls.data));
    if exist('val_results', 'var') && ~isempty(val_results)
        fprintf('Testing  : error %.3g, loss (cls %.3g)\n', ...
            1 - mean(val_results.accuarcy.data), ...
            mean(val_results.loss_cls.data));
    end
    
    % 1016 added for plot
    history_rec.train.accuracy = [history_rec.train.accuracy; 1 - mean(train_results.accuarcy.data)];
    history_rec.train.loss_cls = [history_rec.train.loss_cls; mean(train_results.loss_cls.data)];
    %history_rec.train.loss_bbox = [history_rec.train.loss_bbox; mean(train_results.loss_bbox.data)];
    
    history_rec.val.accuracy = [history_rec.val.accuracy; 1 - mean(val_results.accuarcy.data)];
    history_rec.val.loss_cls = [history_rec.val.loss_cls; mean(val_results.loss_cls.data)];
    %history_rec.val.loss_bbox = [history_rec.val.loss_bbox; mean(val_results.loss_bbox.data)];
    
    history_rec.num = history_rec.num + 1;
    % draw it
    figure(1) ; clf ;
    %plots = {'loss_bbox', 'loss_cls', 'accuracy'};
    plots = {'loss_cls', 'accuracy'};
    for p = plots
      c_p = char(p) ;
      values = zeros(0, history_rec.num) ;
      leg = {} ;
      for f = {'train', 'val'}
        c_f = char(f) ;
        if isfield(history_rec.(c_f), c_p)
          %tmp = [history_rec.(c_f).(c_p)] ;
          %values(end+1,:) = tmp(1,:)' ;
          values(end+1,:) = [history_rec.(c_f).(c_p)]';
          leg{end+1} = c_f;
        end
      end
      subplot(1,numel(plots),find(strcmp(c_p, plots))) ;
      plot(1:history_rec.num, values','o-') ;
      xlabel('epoch') ;
      title(c_p) ;
      legend(leg{:}) ;
      grid on ;
    end
    drawnow ;
    print(1, modelFigPath, '-dpdf') ;
end
