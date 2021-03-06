function save_model_path = proposal_train_widerface_ablation_divanchor(conf, imdb_train, roidb_train, varargin)
% save_model_path = proposal_train_caltech(conf, imdb_train, roidb_train, varargin)
% --------------------------------------------------------
% RPN_BF
% Copyright (c) 2016, Liliang Zhang
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------   
%% -------------------- CONFIG --------------------
% inputs
    ip = inputParser;
    ip.addRequired('conf',                                      @isstruct);
    ip.addRequired('imdb_train',                                @iscell);
    ip.addRequired('roidb_train',                               @iscell);
    ip.addParamValue('do_val',              true,              @isscalar);
    ip.addParamValue('imdb_val',            struct(),           @isstruct);
    ip.addParamValue('roidb_val',           struct(),           @isstruct);
    
    ip.addParamValue('val_iters',           500,                 @isscalar);%1000
    ip.addParamValue('val_interval',        2000,               @isscalar);%5000
    ip.addParamValue('snapshot_interval',...
                                            2000,              @isscalar); %5000
                                                                       
    % Max pixel size of a scaled input image
    ip.addParamValue('solver_def_file',     fullfile(pwd, 'proposal_models', 'Zeiler_conv5', 'solver.prototxt'), ...
                                                        @isstr);
    ip.addParamValue('net_file',            fullfile(pwd, 'proposal_models', 'Zeiler_conv5', 'Zeiler_conv5.caffemodel'), ...
                                                        @isstr);
    ip.addParamValue('cache_name',          'Zeiler_conv5', ...
                                                        @isstr);
                                                    
    ip.addParamValue('exp_name',          'tmp', ...
                                                        @isstr);
                                                    
    ip.addParamValue('empty_image_sample_step',    1,          @isscalar);     
    
    
    
    ip.parse(conf, imdb_train, roidb_train, varargin{:});
    opts = ip.Results;
    
%% try to find trained model
    imdbs_name = cell2mat(cellfun(@(x) x.name, imdb_train, 'UniformOutput', false));
    cache_dir = fullfile(pwd, 'output', opts.exp_name, 'rpn_cachedir', opts.cache_name, imdbs_name);
    %cache_dir = fullfile(pwd, 'output', opts.cache_name, imdbs_name);
    mkdir_if_missing(cache_dir);
	save_model_path = fullfile(cache_dir, 'final');
    if exist(save_model_path, 'file')
        return;
    end

   % in current implentation, we set the ratio of foreground images
   % (which contain at least one pedestrian)
   % as 50% for fully using background images (which contain no pedestrian
   % at all) while balancing their propotion).
   %opts.fg_image_ratio = 0.5;  % no use in widerface
    
%% init  
    % init caffe solver
    %imdbs_name = cell2mat(cellfun(@(x) x.name, imdb_train, 'UniformOutput', false));
    %cache_dir = fullfile(pwd, 'output', opts.exp_name, 'rpn_cachedir', opts.cache_name, imdbs_name);
    %mkdir_if_missing(cache_dir);
    caffe_log_file_base = fullfile(cache_dir, 'caffe_log');
    caffe.init_log(caffe_log_file_base);
    caffe_solver = caffe.Solver(opts.solver_def_file);
    %caffe_solver.net.copy_from(opts.net_file);
    %0316 changed
    caffe_solver.net.copy_from(fullfile(pwd, 'output', 'VGG16_widerface_multibox_ablation_total_noohem', ...
        'rpn_cachedir','rpn_widerface_VGG16_stage1_rpn', 'WIDERFACE_train', 'iter_56000_2nd'));
    
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
    train_roi_name = fullfile(cache_dir, 'train_input_roidb_all.mat');
    test_roi_name = fullfile(cache_dir, 'test_input_roidb_all.mat');
    try
        load(train_roi_name);
    catch
        [image_roidb_train, bbox_mean_s4, bbox_std_s4, bbox_mean_s8, bbox_std_s8, bbox_mean_s16, bbox_std_s16]...
                            = proposal_prepare_image_roidb_ablation_final(conf, opts.imdb_train, opts.roidb_train);
        save(train_roi_name, 'image_roidb_train','bbox_mean_s4', 'bbox_std_s4', 'bbox_mean_s8', 'bbox_std_s8', 'bbox_mean_s16', 'bbox_std_s16','-v7.3');
    end
    fprintf('Done.\n');
    
    if opts.do_val
        fprintf('Preparing validation data...');
        try
            load(test_roi_name);
        catch
            [image_roidb_val]...
                                = proposal_prepare_image_roidb_ablation_final(conf, opts.imdb_val, opts.roidb_val, ...
                                                bbox_mean_s4, bbox_std_s4, bbox_mean_s8, bbox_std_s8, bbox_mean_s16, bbox_std_s16);
            save(test_roi_name, 'image_roidb_val','-v7.3');
        end
        fprintf('Done.\n');

        % fix validation data
        % 1012 changed to use all validation set
        shuffled_inds_val   = generate_random_minibatch([], image_roidb_val, conf.ims_per_batch);
        shuffled_inds_val   = shuffled_inds_val(randperm(length(shuffled_inds_val), opts.val_iters));
        %shuffled_inds_val = num2cell(1:size(image_roidb_val,1));
    end
    
    conf.classes        = opts.imdb_train{1}.classes;
    
%%  try to train/val with images which have maximum size potentially, to validate whether the gpu memory is enough  
    check_gpu_memory(conf, caffe_solver, opts.do_val);
    %1224 added, change caffe_solver's weight
    recover_weights(conf, caffe_solver, bbox_mean_s4, bbox_std_s4, bbox_mean_s8, bbox_std_s8,bbox_mean_s16, bbox_std_s16);
     
%% -------------------- Training -------------------- 

    %proposal_generate_minibatch_fun = @proposal_generate_minibatch_ablation_final;
    proposal_generate_minibatch_fun = @proposal_generate_minibatch_ablation_divanchor_noohem;

    % training
    shuffled_inds = [];
    train_results = [];  
    val_results = [];
    iter_ = caffe_solver.iter();
    max_iter = caffe_solver.max_iter();

    % 0927 added to record plot info
    modelFigPath1 = fullfile(cache_dir, 'net-train-s4.pdf');  % plot save path
    modelFigPath2 = fullfile(cache_dir, 'net-train-s8.pdf');  % plot save path
    modelFigPath3 = fullfile(cache_dir, 'net-train-s16.pdf');  % plot save path
    tmp_struct = struct('err_fg_s4', [], 'err_bg_s4', [], 'loss_cls_s4', [], 'loss_bbox_s4', [], ...
                        'err_fg_s8', [], 'err_bg_s8', [], 'loss_cls_s8', [], 'loss_bbox_s8', [], ...
                        'err_fg_s16', [], 'err_bg_s16', [], 'loss_cls_s16', [], 'loss_bbox_s16', []);
    history_rec = struct('train',tmp_struct,'val',tmp_struct, 'num', 0);
    %1009 changed so that validation can be done within while loop
    while (iter_ <= max_iter)
        % begin time counting
        start_time = tic;
        
        caffe_solver.net.set_phase('train');

        % generate minibatch training data
        [shuffled_inds, sub_db_inds] = generate_random_minibatch(shuffled_inds, image_roidb_train, conf.ims_per_batch);        
        [net_inputs, scale_inds] = proposal_generate_minibatch_fun(conf, image_roidb_train(sub_db_inds));
        
        caffe_solver.net.reshape_as_input(net_inputs);

        % one iter SGD update
        caffe_solver.net.set_input_data(net_inputs);
        caffe_solver.step(1);
        %end time counting
        cost_time = toc(start_time);
%         fprintf('\n');
%         for kk = 1:length(caffe_blob_names)
%            blob_der_compare(caffe_solver.net, caffe_blob_names{kk}, der_cell{mat_blob_indices(2*kk-1)}, der_cell{mat_blob_indices(2*kk)}); 
%         end
%         fprintf('\n');
        
        rst = caffe_solver.net.get_output();
        rst = check_error(rst, caffe_solver);
        
        %format long
        % 0227: for single batch
%         fprintf('Iter %d, Image %d: %.1f Hz, ', iter_, sub_db_inds, 1/cost_time);
%         for kkk = [2 5 8 10 11]
%             fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
%         end
%         fprintf('\n\t\t\t    ');
%         for kkk = [3 6 9 12 13]
%             fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
%         end
%         fprintf('\n\t\t\t    ');  %print conv6
%         for kkk = [1 4 7 14 15]
%             fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
%         end
%         fprintf('\n');
        % 0227 for batch 3
        fprintf('Iter %d, Image %d, %d: %.1f Hz, ', iter_, sub_db_inds(1), sub_db_inds(2), 1/cost_time);
        fprintf('\n\t');
        for kkk = [2 5 8 10 11]
            fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
        end
        fprintf('\n\t');
        for kkk = [3 6 9 12 13]
            fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
        end
        fprintf('\n\t');  %print conv6
        for kkk = [1 4 7 14 15]
            fprintf('%s = %.4f, ',rst(kkk).blob_name, rst(kkk).data); 
        end
        fprintf('\n');
        
        train_results = parse_rst(train_results, rst);
        % check_loss(rst, caffe_solver, net_inputs);

        % do valdiation per val_interval iterations
        if ~mod(iter_, opts.val_interval) 
            if opts.do_val
                val_results = do_validation(conf, caffe_solver, proposal_generate_minibatch_fun, image_roidb_val, shuffled_inds_val);
            end
            % 0927 changed: showstate + plot
            %show_state(iter_, train_results, val_results);
            history_rec = show_state_and_plot(iter_, train_results, val_results, history_rec, modelFigPath1, modelFigPath2, modelFigPath3);
            
            %show_state(iter_, train_results, val_results);
            train_results = [];
            diary; diary; % flush diary
        end
        
        % snapshot
        if ~mod(iter_, opts.snapshot_interval)
            snapshot(conf, caffe_solver, bbox_mean_s4, bbox_std_s4, bbox_mean_s8, bbox_std_s8,bbox_mean_s16, bbox_std_s16, cache_dir, sprintf('iter_%d', iter_));
        end
        
        iter_ = caffe_solver.iter();
    end
    
    % final validation
    % liu@0927 commented, because now all validation can be done during while loop
    %if opts.do_val
    %    do_validation(conf, caffe_solver, proposal_generate_minibatch_fun, image_roidb_val, shuffled_inds_val);
    %end
    % final snapshot
    % liu@0927 commented, because now all snapshot can be done during while loop
    %snapshot(conf, caffe_solver, bbox_means, bbox_stds, cache_dir, sprintf('iter_%d', iter_));
    save_model_path = snapshot(conf, caffe_solver, bbox_mean_s4, bbox_std_s4, bbox_mean_s8, bbox_std_s8,bbox_mean_s16, bbox_std_s16, cache_dir, 'final');

    diary off;
    caffe.reset_all(); 
    rng(prev_rng);
 
end

function val_results = do_validation(conf, caffe_solver, proposal_generate_minibatch_fun, image_roidb_val, shuffled_inds_val)
    % before each validation clear the history results
    val_results = [];

    caffe_solver.net.set_phase('test');
    for i = 1:length(shuffled_inds_val)
        sub_db_inds = shuffled_inds_val{i};
        [net_inputs, ~] = proposal_generate_minibatch_fun(conf, image_roidb_val(sub_db_inds));

        % Reshape net's input blobs
        caffe_solver.net.reshape_as_input(net_inputs);

        caffe_solver.net.forward(net_inputs);
        rst = caffe_solver.net.get_output();
        rst = check_error(rst, caffe_solver);  
        val_results = parse_rst(val_results, rst);
    end
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

function rst = check_error(rst, caffe_solver)
    % stride 4
    cls_score = caffe_solver.net.blobs('proposal_cls_score_reshape_s4').get_data();
    labels = caffe_solver.net.blobs('labels_reshape_s4').get_data();
    labels_weights = caffe_solver.net.blobs('labels_weights_reshape_s4').get_data();
    
    accurate_fg = (cls_score(:, :, 2, :) > cls_score(:, :, 1, :)) & (labels == 1);
    accurate_bg = (cls_score(:, :, 2, :) <= cls_score(:, :, 1, :)) & (labels == 0);
    accuracy_fg_s4 = sum(accurate_fg(:) .* labels_weights(:)) / (sum(labels_weights(labels == 1)) + eps);
    accuracy_bg_s4 = sum(accurate_bg(:) .* labels_weights(:)) / (sum(labels_weights(labels == 0)) + eps);
    % stride 8
    cls_score = caffe_solver.net.blobs('proposal_cls_score_reshape_s8').get_data();
    labels = caffe_solver.net.blobs('labels_reshape_s8').get_data();
    labels_weights = caffe_solver.net.blobs('labels_weights_reshape_s8').get_data();
    
    accurate_fg = (cls_score(:, :, 2, :) > cls_score(:, :, 1, :)) & (labels == 1);
    accurate_bg = (cls_score(:, :, 2, :) <= cls_score(:, :, 1, :)) & (labels == 0);
    accuracy_fg_s8 = sum(accurate_fg(:) .* labels_weights(:)) / (sum(labels_weights(labels == 1)) + eps);
    accuracy_bg_s8 = sum(accurate_bg(:) .* labels_weights(:)) / (sum(labels_weights(labels == 0)) + eps);
    
    % stride 16
    cls_score = caffe_solver.net.blobs('proposal_cls_score_reshape_s16').get_data();
    labels = caffe_solver.net.blobs('labels_reshape_s16').get_data();
    labels_weights = caffe_solver.net.blobs('labels_weights_reshape_s16').get_data();
    
    accurate_fg = (cls_score(:, :, 2, :) > cls_score(:, :, 1, :)) & (labels == 1);
    accurate_bg = (cls_score(:, :, 2, :) <= cls_score(:, :, 1, :)) & (labels == 0);
    accuracy_fg_s16 = sum(accurate_fg(:) .* labels_weights(:)) / (sum(labels_weights(labels == 1)) + eps);
    accuracy_bg_s16 = sum(accurate_bg(:) .* labels_weights(:)) / (sum(labels_weights(labels == 0)) + eps);
    
    rst(end+1) = struct('blob_name', 'accuracy_fg_s4', 'data', accuracy_fg_s4);
    rst(end+1) = struct('blob_name', 'accuracy_bg_s4', 'data', accuracy_bg_s4);
    rst(end+1) = struct('blob_name', 'accuracy_fg_s8', 'data', accuracy_fg_s8);
    rst(end+1) = struct('blob_name', 'accuracy_bg_s8', 'data', accuracy_bg_s8);
    rst(end+1) = struct('blob_name', 'accuracy_fg_s16', 'data', accuracy_fg_s16);
    rst(end+1) = struct('blob_name', 'accuracy_bg_s16', 'data', accuracy_bg_s16);
end

function check_gpu_memory(conf, caffe_solver, do_val)
%%  try to train/val with images which have maximum size potentially, to validate whether the gpu memory is enough  

    % generate pseudo training data with max size
    im_size = [max(conf.scales), conf.max_size];
    im_size = ceil(im_size/8) * 8;
    im_blob = single(zeros(im_size(1), im_size(2), 3, conf.ims_per_batch));
    % stride4
    anchor_num_s4 = size(conf.anchors_s4, 1);
    output_width = conf.output_width_s4.values({size(im_blob, 1)});
    output_width = output_width{1};
    output_height = conf.output_height_s4.values({size(im_blob, 2)});
    output_height = output_height{1};
    labels_blob_s4 = single(zeros(output_width, output_height, anchor_num_s4, conf.ims_per_batch));
    labels_weights_s4 = labels_blob_s4;
    bbox_targets_blob_s4 = single(zeros(output_width, output_height, anchor_num_s4*4, conf.ims_per_batch));
    bbox_loss_weights_blob_s4 = bbox_targets_blob_s4;
    % stride8
    anchor_num_s8 = size(conf.anchors_s8, 1);
    output_width = conf.output_width_s8.values({size(im_blob, 1)});
    output_width = output_width{1};
    output_height = conf.output_height_s8.values({size(im_blob, 2)});
    output_height = output_height{1};
    labels_blob_s8 = single(zeros(output_width, output_height, anchor_num_s8, conf.ims_per_batch));
    labels_weights_s8 = labels_blob_s8;
    bbox_targets_blob_s8 = single(zeros(output_width, output_height, anchor_num_s8*4, conf.ims_per_batch));
    bbox_loss_weights_blob_s8 = bbox_targets_blob_s8;
    % stride16
    anchor_num_s16 = size(conf.anchors_s16, 1);
    output_width = conf.output_width_s16.values({size(im_blob, 1)});
    output_width = output_width{1};
    output_height = conf.output_height_s16.values({size(im_blob, 2)});
    output_height = output_height{1};
    labels_blob_s16 = single(zeros(output_width, output_height, anchor_num_s16, conf.ims_per_batch));
    labels_weights_s16 = labels_blob_s16;
    bbox_targets_blob_s16 = single(zeros(output_width, output_height, anchor_num_s16*4, conf.ims_per_batch));
    bbox_loss_weights_blob_s16 = bbox_targets_blob_s16;

    net_inputs = {im_blob, labels_blob_s4, labels_weights_s4, bbox_targets_blob_s4, bbox_loss_weights_blob_s4, ...
                            labels_blob_s8, labels_weights_s8, bbox_targets_blob_s8, bbox_loss_weights_blob_s8,...
                            labels_blob_s16, labels_weights_s16, bbox_targets_blob_s16, bbox_loss_weights_blob_s16};
    
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

function model_path = snapshot(conf, caffe_solver, bbox_mean_s4, bbox_std_s4, bbox_mean_s8, bbox_std_s8,bbox_mean_s16, bbox_std_s16, cache_dir, file_name)
    % ============================
    % stride4
    anchor_size_s4 = size(conf.anchors_s4, 1);
    bbox_stds_flatten = repmat(reshape(bbox_std_s4', [], 1), anchor_size_s4, 1);
    bbox_means_flatten = repmat(reshape(bbox_mean_s4', [], 1), anchor_size_s4, 1);
    
    % merge bbox_means, bbox_stds into the model
    bbox_pred_layer_name_s4 = 'proposal_bbox_pred_s4';
    weights = caffe_solver.net.params(bbox_pred_layer_name_s4, 1).get_data();
    biase = caffe_solver.net.params(bbox_pred_layer_name_s4, 2).get_data();
    weights_back_s4 = weights;
    biase_back_s4 = biase;
    
    weights = ...
        bsxfun(@times, weights, permute(bbox_stds_flatten, [2, 3, 4, 1])); % weights = weights * stds; 
    biase = ...
        biase .* bbox_stds_flatten + bbox_means_flatten; % bias = bias * stds + means;
    
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s4, 1, weights);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s4, 2, biase);
    
    % ========================
    % stride 8
    anchor_size_s8 = size(conf.anchors_s8, 1);
    bbox_stds_flatten = repmat(reshape(bbox_std_s8', [], 1), anchor_size_s8, 1);
    bbox_means_flatten = repmat(reshape(bbox_mean_s8', [], 1), anchor_size_s8, 1);
    
    % merge bbox_means, bbox_stds into the model
    bbox_pred_layer_name_s8 = 'proposal_bbox_pred_s8';
    weights = caffe_solver.net.params(bbox_pred_layer_name_s8, 1).get_data();
    biase = caffe_solver.net.params(bbox_pred_layer_name_s8, 2).get_data();
    weights_back_s8 = weights;
    biase_back_s8 = biase;
    
    weights = ...
        bsxfun(@times, weights, permute(bbox_stds_flatten, [2, 3, 4, 1])); % weights = weights * stds; 
    biase = ...
        biase .* bbox_stds_flatten + bbox_means_flatten; % bias = bias * stds + means;
    
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s8, 1, weights);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s8, 2, biase);
    
    % ================================
    % conv16
    anchor_size_s16 = size(conf.anchors_s16, 1);
    bbox_stds_flatten = repmat(reshape(bbox_std_s16', [], 1), anchor_size_s16, 1);
    bbox_means_flatten = repmat(reshape(bbox_mean_s16', [], 1), anchor_size_s16, 1);
    
    % merge bbox_means, bbox_stds into the model
    bbox_pred_layer_name_s16 = 'proposal_bbox_pred_s16';
    weights = caffe_solver.net.params(bbox_pred_layer_name_s16, 1).get_data();
    biase = caffe_solver.net.params(bbox_pred_layer_name_s16, 2).get_data();
    weights_back_s16 = weights;
    biase_back_s16 = biase;
    
    weights = ...
        bsxfun(@times, weights, permute(bbox_stds_flatten, [2, 3, 4, 1])); % weights = weights * stds; 
    biase = ...
        biase .* bbox_stds_flatten + bbox_means_flatten; % bias = bias * stds + means;
    
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s16, 1, weights);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s16, 2, biase);
    
    model_path = fullfile(cache_dir, file_name);
    caffe_solver.net.save(model_path);
    fprintf('Saved as %s\n', model_path);
    
    % restore net to original state
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s4, 1, weights_back_s4);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s4, 2, biase_back_s4);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s8, 1, weights_back_s8);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s8, 2, biase_back_s8);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s16, 1, weights_back_s16);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_s16, 2, biase_back_s16);
end

function recover_weights(conf, caffe_solver, bbox_means_conv4, bbox_stds_conv4, bbox_means_conv5, bbox_stds_conv5,bbox_means_conv6, bbox_stds_conv6)
    % conv4
    % ================================
    anchor_size_conv4 = size(conf.anchors_s4, 1);
    bbox_stds_flatten = repmat(reshape(bbox_stds_conv4', [], 1), anchor_size_conv4, 1);
    bbox_means_flatten = repmat(reshape(bbox_means_conv4', [], 1), anchor_size_conv4, 1);
    
    % merge bbox_means, bbox_stds into the model
    bbox_pred_layer_name_conv4 = 'proposal_bbox_pred_s4';
    weights = caffe_solver.net.params(bbox_pred_layer_name_conv4, 1).get_data();
    biase = caffe_solver.net.params(bbox_pred_layer_name_conv4, 2).get_data();
    
    weights = ...
        bsxfun(@rdivide, weights, permute(bbox_stds_flatten, [2, 3, 4, 1])); % weights = weights * stds (@times)==> weights = weights / stds (@rdivide)
    biase = ...
        (biase - bbox_means_flatten) ./ bbox_stds_flatten; % bias = bias * stds + means ==> bias = (bias - means) / stds
    
    caffe_solver.net.set_params_data(bbox_pred_layer_name_conv4, 1, weights);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_conv4, 2, biase);
    
    % conv5
    % ================================
    anchor_size_conv5 = size(conf.anchors_s8, 1);
    bbox_stds_flatten = repmat(reshape(bbox_stds_conv5', [], 1), anchor_size_conv5, 1);
    bbox_means_flatten = repmat(reshape(bbox_means_conv5', [], 1), anchor_size_conv5, 1);
    
    % merge bbox_means, bbox_stds into the model
    bbox_pred_layer_name_conv5 = 'proposal_bbox_pred_s8';
    weights = caffe_solver.net.params(bbox_pred_layer_name_conv5, 1).get_data();
    biase = caffe_solver.net.params(bbox_pred_layer_name_conv5, 2).get_data();
    
    weights = ...
        bsxfun(@rdivide, weights, permute(bbox_stds_flatten, [2, 3, 4, 1])); % weights = weights * stds (@times)==> weights = weights / stds (@rdivide)
    biase = ...
        (biase - bbox_means_flatten) ./ bbox_stds_flatten; % bias = bias * stds + means ==> bias = (bias - means) / stds
    
    caffe_solver.net.set_params_data(bbox_pred_layer_name_conv5, 1, weights);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_conv5, 2, biase);
    
    % conv6
    % ================================
    anchor_size_conv6 = size(conf.anchors_s16, 1);
    bbox_stds_flatten = repmat(reshape(bbox_stds_conv6', [], 1), anchor_size_conv6, 1);
    bbox_means_flatten = repmat(reshape(bbox_means_conv6', [], 1), anchor_size_conv6, 1);
    
    % merge bbox_means, bbox_stds into the model
    bbox_pred_layer_name_conv6 = 'proposal_bbox_pred_s16';
    weights = caffe_solver.net.params(bbox_pred_layer_name_conv6, 1).get_data();
    biase = caffe_solver.net.params(bbox_pred_layer_name_conv6, 2).get_data();
    
    weights = ...
        bsxfun(@rdivide, weights, permute(bbox_stds_flatten, [2, 3, 4, 1])); % weights = weights * stds (@times)==> weights = weights / stds (@rdivide)
    biase = ...
        (biase - bbox_means_flatten) ./ bbox_stds_flatten; % bias = bias * stds + means ==> bias = (bias - means) / stds
    
    caffe_solver.net.set_params_data(bbox_pred_layer_name_conv6, 1, weights);
    caffe_solver.net.set_params_data(bbox_pred_layer_name_conv6, 2, biase);
end

%function show_state(iter, train_results, val_results)
function history_rec = show_state_and_plot(iter, train_results, val_results, history_rec, modelFigPath1, modelFigPath2, modelFigPath3)
        % --------- begin previously show_state part ------------
    fprintf('\n------------------------- Iteration %d -------------------------\n', iter);
    fprintf('Training : err_fg_s4 %.3g, err_bg_s4 %.3g, loss_s4 (cls %.3g + reg %.3g)\n', ...
        1 - mean(train_results.accuracy_fg_s4.data), 1 - mean(train_results.accuracy_bg_s4.data), ...
        mean(train_results.loss_cls_s4.data), ...
        mean(train_results.loss_bbox_s4.data));
    fprintf('\t err_fg_s8 %.3g, err_bg_s8 %.3g, loss_s8 (cls %.3g + reg %.3g)\n', ...
        1 - mean(train_results.accuracy_fg_s8.data), 1 - mean(train_results.accuracy_bg_s8.data), ...
        mean(train_results.loss_cls_s8.data), ...
        mean(train_results.loss_bbox_s8.data));
    fprintf('\t err_fg_s16 %.3g, err_bg_s16 %.3g, loss_s16 (cls %.3g + reg %.3g)\n', ...
        1 - mean(train_results.accuracy_fg_s16.data), 1 - mean(train_results.accuracy_bg_s16.data), ...
        mean(train_results.loss_cls_s16.data), ...
        mean(train_results.loss_bbox_s16.data));
    
    if exist('val_results', 'var') && ~isempty(val_results)
        fprintf('Testing  : err_fg_s4 %.3g, err_bg_s4 %.3g, loss_s4 (cls %.3g + reg %.3g)\n', ...
            1 - mean(val_results.accuracy_fg_s4.data), 1 - mean(val_results.accuracy_bg_s4.data), ...
            mean(val_results.loss_cls_s4.data), ...
            mean(val_results.loss_bbox_s4.data));
        fprintf('\t err_fg_s8 %.3g, err_bg_s8 %.3g, loss_s8 (cls %.3g + reg %.3g)\n', ...
            1 - mean(val_results.accuracy_fg_s8.data), 1 - mean(val_results.accuracy_bg_s8.data), ...
            mean(val_results.loss_cls_s8.data), ...
            mean(val_results.loss_bbox_s8.data));
        fprintf('\t err_fg_s16 %.3g, err_bg_s16 %.3g, loss_s16 (cls %.3g + reg %.3g)\n', ...
            1 - mean(val_results.accuracy_fg_s16.data), 1 - mean(val_results.accuracy_bg_s16.data), ...
            mean(val_results.loss_cls_s16.data), ...
            mean(val_results.loss_bbox_s16.data));
    end
    % --------- end previously show_state part ------------
    % ========= newly added plot part =====================
    %conv4
    history_rec.train.err_fg_s4 = [history_rec.train.err_fg_s4; 1 - mean(train_results.accuracy_fg_s4.data)];
    history_rec.train.err_bg_s4 = [history_rec.train.err_bg_s4; 1 - mean(train_results.accuracy_bg_s4.data)];
    history_rec.train.loss_cls_s4 = [history_rec.train.loss_cls_s4; mean(train_results.loss_cls_s4.data)];
    history_rec.train.loss_bbox_s4 = [history_rec.train.loss_bbox_s4; mean(train_results.loss_bbox_s4.data)];
    history_rec.val.err_fg_s4 = [history_rec.val.err_fg_s4; 1 - mean(val_results.accuracy_fg_s4.data)];
    history_rec.val.err_bg_s4 = [history_rec.val.err_bg_s4; 1 - mean(val_results.accuracy_bg_s4.data)];
    history_rec.val.loss_cls_s4 = [history_rec.val.loss_cls_s4; mean(val_results.loss_cls_s4.data)];
    history_rec.val.loss_bbox_s4 = [history_rec.val.loss_bbox_s4; mean(val_results.loss_bbox_s4.data)];
    %conv5
    history_rec.train.err_fg_s8 = [history_rec.train.err_fg_s8; 1 - mean(train_results.accuracy_fg_s8.data)];
    history_rec.train.err_bg_s8 = [history_rec.train.err_bg_s8; 1 - mean(train_results.accuracy_bg_s8.data)];
    history_rec.train.loss_cls_s8 = [history_rec.train.loss_cls_s8; mean(train_results.loss_cls_s8.data)];
    history_rec.train.loss_bbox_s8 = [history_rec.train.loss_bbox_s8; mean(train_results.loss_bbox_s8.data)];
    history_rec.val.err_fg_s8 = [history_rec.val.err_fg_s8; 1 - mean(val_results.accuracy_fg_s8.data)];
    history_rec.val.err_bg_s8 = [history_rec.val.err_bg_s8; 1 - mean(val_results.accuracy_bg_s8.data)];
    history_rec.val.loss_cls_s8 = [history_rec.val.loss_cls_s8; mean(val_results.loss_cls_s8.data)];
    history_rec.val.loss_bbox_s8 = [history_rec.val.loss_bbox_s8; mean(val_results.loss_bbox_s8.data)];
    %conv6
    history_rec.train.err_fg_s16 = [history_rec.train.err_fg_s16; 1 - mean(train_results.accuracy_fg_s16.data)];
    history_rec.train.err_bg_s16 = [history_rec.train.err_bg_s16; 1 - mean(train_results.accuracy_bg_s16.data)];
    history_rec.train.loss_cls_s16 = [history_rec.train.loss_cls_s16; mean(train_results.loss_cls_s16.data)];
    history_rec.train.loss_bbox_s16 = [history_rec.train.loss_bbox_s16; mean(train_results.loss_bbox_s16.data)];
    history_rec.val.err_fg_s16 = [history_rec.val.err_fg_s16; 1 - mean(val_results.accuracy_fg_s16.data)];
    history_rec.val.err_bg_s16 = [history_rec.val.err_bg_s16; 1 - mean(val_results.accuracy_bg_s16.data)];
    history_rec.val.loss_cls_s16 = [history_rec.val.loss_cls_s16; mean(val_results.loss_cls_s16.data)];
    history_rec.val.loss_bbox_s16 = [history_rec.val.loss_bbox_s16; mean(val_results.loss_bbox_s16.data)];
    
    history_rec.num = history_rec.num + 1;
    % draw it
    figure(1) ; clf ;
    titles1 = {'err\_fg\_s4', 'err\_bg\_s4', 'loss\_cls\_s4', 'loss\_bbox\_s4'};
    plots1 = {'err_fg_s4', 'err_bg_s4', 'loss_cls_s4', 'loss_bbox_s4'};

    %half_plot_num = ceil(numel(plots)/2);
    cnt = 0;
    for p = plots1
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
      %subplot(2, half_plot_num,find(strcmp(c_p, plots)));
      subplot(1,numel(plots1),find(strcmp(c_p, plots1))) ;
      plot(1:history_rec.num, values','o-') ;
      xlabel('epoch') ;
      cnt = cnt + 1;
      %title(c_p) ;
      title(titles1(cnt)) ;
      legend(leg{:}) ;
      grid on ;
    end
    drawnow ;
    print(1, modelFigPath1, '-dpdf') ;
    
    % for conv5
    figure(2) ; clf ;
    titles2 = {'err\_fg\_s8', 'err\_bg\_s8', 'loss\_cls\_s8', 'loss\_bbox\_s8'};
    plots2 = {'err_fg_s8', 'err_bg_s8', 'loss_cls_s8', 'loss_bbox_s8'};

    %half_plot_num = ceil(numel(plots)/2);
    cnt = 0;
    for p = plots2
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
      %subplot(2, half_plot_num,find(strcmp(c_p, plots)));
      subplot(1,numel(plots2),find(strcmp(c_p, plots2))) ;
      plot(1:history_rec.num, values','o-') ;
      xlabel('epoch') ;
      cnt = cnt + 1;
      %title(c_p) ;
      title(titles2(cnt)) ;
      legend(leg{:}) ;
      grid on ;
    end
    drawnow ;
    print(2, modelFigPath2, '-dpdf') ;
    
    % for conv6
    figure(3) ; clf ;
    titles3 = {'err\_fg\_s16', 'err\_bg\_s16', 'loss\_cls\_s16', 'loss\_bbox\_s16'};
    plots3 = {'err_fg_s16', 'err_bg_s16', 'loss_cls_s16', 'loss_bbox_s16'};

    %half_plot_num = ceil(numel(plots)/2);
    cnt = 0;
    for p = plots3
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
      %subplot(2, half_plot_num,find(strcmp(c_p, plots)));
      subplot(1,numel(plots3),find(strcmp(c_p, plots3))) ;
      plot(1:history_rec.num, values','o-') ;
      xlabel('epoch') ;
      cnt = cnt + 1;
      %title(c_p) ;
      title(titles3(cnt)) ;
      legend(leg{:}) ;
      grid on ;
    end
    drawnow ;
    print(3, modelFigPath3, '-dpdf') ;
end

function check_loss(rst, caffe_solver, input_blobs)
    im_blob = input_blobs{1};
    labels_blob = input_blobs{2};
    label_weights_blob = input_blobs{3};
    bbox_targets_blob = input_blobs{4};
    bbox_loss_weights_blob = input_blobs{5};
    
    regression_output = caffe_solver.net.blobs('proposal_bbox_pred').get_data();
    % smooth l1 loss
    regression_delta = abs(regression_output(:) - bbox_targets_blob(:));
    regression_delta_l2 = regression_delta < 1;
    regression_delta = 0.5 * regression_delta .* regression_delta .* regression_delta_l2 + (regression_delta - 0.5) .* ~regression_delta_l2;
    regression_loss = sum(regression_delta.* bbox_loss_weights_blob(:)) / size(regression_output, 1) / size(regression_output, 2);
    
    confidence = caffe_solver.net.blobs('proposal_cls_score_reshape').get_data();
    labels = reshape(labels_blob, size(labels_blob, 1), []);
    label_weights = reshape(label_weights_blob, size(label_weights_blob, 1), []);
    
    confidence_softmax = bsxfun(@rdivide, exp(confidence), sum(exp(confidence), 3));
    confidence_softmax = reshape(confidence_softmax, [], 2);
    confidence_loss = confidence_softmax(sub2ind(size(confidence_softmax), 1:size(confidence_softmax, 1), labels(:)' + 1));
    confidence_loss = -log(confidence_loss);
    confidence_loss = sum(confidence_loss' .* label_weights(:)) / sum(label_weights(:));
    
    results = parse_rst([], rst);
    fprintf('C++   : conf %f, reg %f\n', results.loss_cls.data, results.loss_bbox.data);
    fprintf('Matlab: conf %f, reg %f\n', confidence_loss, regression_loss);
end
