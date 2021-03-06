function [aboxes_res23, aboxes_res45] = proposal_test_widerface_twopath_happy_flip_vn7(conf, imdb, varargin)
% aboxes = proposal_test_caltech(conf, imdb, varargin)
% --------------------------------------------------------
% RPN_BF
% Copyright (c) 2016, Liliang Zhang
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------   

%% inputs
    ip = inputParser;
    ip.addRequired('conf',                              @isstruct);
    ip.addRequired('imdb',                              @isstruct);
    ip.addParamValue('net_def_file',    fullfile(pwd, 'proposal_models', 'Zeiler_conv5', 'test.prototxt'), ...
                                                        @isstr);
    ip.addParamValue('net_file',        fullfile(pwd, 'proposal_models', 'Zeiler_conv5', 'Zeiler_conv5.caffemodel'), ...
                                                        @isstr);
    ip.addParamValue('cache_name',      'Zeiler_conv5', ...
                                                        @isstr);
                                                    
    ip.addParamValue('suffix',          '',             @isstr);
    
    ip.parse(conf, imdb, varargin{:});
    opts = ip.Results;
    
    %##### note@1013:every time you want to regenerate bboxes, need to
    %delete the proposal_boxes_*.mat file in
    %output/VGG16_wider*/rpn_cachedir/rpn_widerface_VGG16_stage1_rpn
    cache_dir = fullfile(pwd, 'output', conf.exp_name, 'rpn_cachedir', opts.cache_name, imdb.name);
	%cache_dir = fullfile(pwd, 'output', opts.cache_name, imdb.name);
    try
        % try to load cache
        ld = load(fullfile(cache_dir, ['proposal_boxes_' imdb.name opts.suffix]));
        aboxes_res23 = ld.aboxes_res23;
        aboxes_res45 = ld.aboxes_res45;
        clear ld;
    catch    
        %% init net
        % init caffe net
        mkdir_if_missing(cache_dir);
        caffe_log_file_base = fullfile(cache_dir, 'caffe_log');
        caffe.init_log(caffe_log_file_base);
        caffe_net = caffe.Net(opts.net_def_file, 'test');
        caffe_net.copy_from(opts.net_file);

        % init log
        timestamp = datestr(datevec(now()), 'yyyymmdd_HHMMSS');
        mkdir_if_missing(fullfile(cache_dir, 'log'));
        log_file = fullfile(cache_dir, 'log', ['test_', timestamp, '.txt']);
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

        disp('opts:');
        disp(opts);
        disp('conf:');
        disp(conf);
    
%% testing
        num_images = length(imdb.image_ids);
        % all detections are collected into:
        %    all_boxes[image] = N x 5 array of detections in
        %    (x1, y1, x2, y2, score)
        aboxes_res23 = cell(num_images, 1);
        aboxes_res45 = cell(num_images, 1);
        
        count = 0;
        for i = 1:num_images
            count = count + 1;
            fprintf('%s: test (%s) %d/%d ', procid(), imdb.name, count, num_images);
            th = tic;
            im = imread(imdb.image_at(i));

            %[boxes, scores, abox_deltas{i}, aanchors{i}, ascores{i}] = proposal_im_detect_multibox(conf, caffe_net, im);
            [boxes_res23, scores_res23, boxes_res45, scores_res45] = proposal_im_detect_twopath_happy_flip_scale3(conf, caffe_net, im);
            %[boxes, scores] = proposal_im_detect_multibox(conf, caffe_net, im);
            
            fprintf(' time: %.3fs\n', toc(th)); 
            
            aboxes23_tmp = cell(1, numel(scores_res23));
            aboxes45_tmp = cell(1, numel(scores_res23));
            for j = 1:numel(scores_res23)
                %1230 added
                boxes_res23{j} = boxes_res23{j}(scores_res23{j} >= 0.6,:);
                scores_res23{j} = scores_res23{j}(scores_res23{j} >= 0.6,:);  %0101:0.1-->0.55

                boxes_res45{j} = boxes_res45{j}(scores_res45{j} >= 0.6,:);
                scores_res45{j} = scores_res45{j}(scores_res45{j} >= 0.6,:);

                aboxes23_tmp{j} = [boxes_res23{j}, scores_res23{j}];
                aboxes_res23{i} = cat(1, aboxes_res23{i}, aboxes23_tmp{j});
                aboxes45_tmp{j} = [boxes_res45{j}, scores_res45{j}];
                aboxes_res45{i} = cat(1, aboxes_res45{i}, aboxes45_tmp{j});
            end
            if 0
                % debugging visualizations
                im = imread(imdb.image_at(i));
                figure(1),clf;
                imshow(im);
                color_cell23 = {'g', 'c', 'm'};
                color_cell45 = {'r', 'b', 'y'};
                hold on
                for j = 1:numel(scores_res23)
                    keep = nms(aboxes23_tmp{j}, 0.3);
                    bbs_show = aboxes23_tmp{j}(keep, :);
                    bbs_show = bbs_show(bbs_show(:,5)>=0.9, :);
                    bbs_show(:, 3) = bbs_show(:, 3) - bbs_show(:, 1) + 1;
                    bbs_show(:, 4) = bbs_show(:, 4) - bbs_show(:, 2) + 1;
                    bbApply('draw',bbs_show,color_cell23{j});
                end
                for j = 1:numel(scores_res45)
                    keep = nms(aboxes45_tmp{j}, 0.3);
                    bbs_show = aboxes45_tmp{j}(keep, :);
                    bbs_show = bbs_show(bbs_show(:,5)>=0.9, :);
                    bbs_show(:, 3) = bbs_show(:, 3) - bbs_show(:, 1) + 1;
                    bbs_show(:, 4) = bbs_show(:, 4) - bbs_show(:, 2) + 1;
                    bbApply('draw',bbs_show,color_cell45{j});
                end
                hold off
            end
        end    
        save(fullfile(cache_dir, ['proposal_boxes_' imdb.name opts.suffix]), 'aboxes_res23', 'aboxes_res45', '-v7.3');
        
        diary off;
        caffe.reset_all(); 
        rng(prev_rng);
    end
end
