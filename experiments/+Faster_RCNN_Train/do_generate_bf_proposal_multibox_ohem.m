function roidb_BF = do_generate_bf_proposal_multibox_ohem(conf, model_stage, imdb, roidb, is_test)
    
    cache_dir = fullfile(pwd, 'output', conf.exp_name, 'rpn_cachedir', model_stage.cache_name, imdb.name);
    %cache_dir = fullfile(pwd, 'output', model_stage.cache_name, imdb.name);
    %save_roidb_name = fullfile(cache_dir, [ 'roidb_' imdb.name '_BF.mat']);
    %1011 changed
    save_roidb_name = fullfile(cache_dir, [ 'roidb_' imdb.name '_BF.mat']);
    if exist(save_roidb_name, 'file')
        ld = load(save_roidb_name);
        roidb_BF = ld.roidb_BF;
        clear ld;
        return;
    end
    % **** 1201 ***** currently only do BF for conv4 
    % aboxes_conv4 is the raw bbox output of conv4
    [aboxes_conv4, aboxes_conv5, aboxes_conv6]     = proposal_test_widerface_multibox_final3(conf, imdb, ...
                                        'net_def_file',     model_stage.test_net_def_file, ...
                                        'net_file',         model_stage.output_model_file, ...
                                        'cache_name',       model_stage.cache_name); 
    
    fprintf('Doing nms ... ');   
    % liu@1001: model_stage.nms.after_nms_topN functions as a threshold, indicating how many boxes will be preserved on average
    %ave_per_image_topN = model_stage.nms.after_nms_topN;
    %model_stage.nms.after_nms_topN = -1;
    ave_per_image_topN_conv4 = model_stage.nms.after_nms_topN_conv4; % conv4
    ave_per_image_topN_conv5 = model_stage.nms.after_nms_topN_conv5; % conv5
    ave_per_image_topN_conv6 = model_stage.nms.after_nms_topN_conv6; % conv6
    model_stage.nms.after_nms_topN_conv4 = -1;
    model_stage.nms.after_nms_topN_conv5 = -1;
    model_stage.nms.after_nms_topN_conv6 = -1;
    %aboxes                      = boxes_filter(aboxes, model_stage.nms.per_nms_topN, model_stage.nms.nms_overlap_thres, model_stage.nms.after_nms_topN, conf.use_gpu);      
    aboxes_conv4              = boxes_filter(aboxes_conv4, model_stage.nms.per_nms_topN, model_stage.nms.nms_overlap_thres_conv4, model_stage.nms.after_nms_topN_conv4, conf.use_gpu);
    aboxes_conv5              = boxes_filter(aboxes_conv5, model_stage.nms.per_nms_topN, model_stage.nms.nms_overlap_thres_conv5, model_stage.nms.after_nms_topN_conv5, conf.use_gpu);
    aboxes_conv6              = boxes_filter(aboxes_conv6, model_stage.nms.per_nms_topN, model_stage.nms.nms_overlap_thres_conv6, model_stage.nms.after_nms_topN_conv6, conf.use_gpu);
    fprintf(' Done.\n');  
    
    % only use the first max_sample_num images to compute an "expected" lower bound thresh
    max_sample_num = 5000;
    % conv4
    sample_aboxes = aboxes_conv4(randperm(length(aboxes_conv4), min(length(aboxes_conv4), max_sample_num)));  % conv4 and conv5 are the same, so just use conv4
    scores = zeros(ave_per_image_topN_conv4*length(sample_aboxes), 1);
    for i = 1:length(sample_aboxes)
        s_scores = sort([scores; sample_aboxes{i}(:, end)], 'descend');
        scores = s_scores(1:ave_per_image_topN_conv4*length(sample_aboxes));
    end
    score_thresh_conv4 = scores(end);
    
    % conv5
    sample_aboxes = aboxes_conv5(randperm(length(aboxes_conv5), min(length(aboxes_conv5), max_sample_num)));  % conv4 and conv5 are the same, so just use conv4
    scores = zeros(ave_per_image_topN_conv5*length(sample_aboxes), 1);
    for i = 1:length(sample_aboxes)
        s_scores = sort([scores; sample_aboxes{i}(:, end)], 'descend');
        scores = s_scores(1:ave_per_image_topN_conv5*length(sample_aboxes));
    end
    score_thresh_conv5 = scores(end);
    
    % conv6
    sample_aboxes = aboxes_conv6(randperm(length(aboxes_conv6), min(length(aboxes_conv6), max_sample_num)));  % conv4 and conv5 are the same, so just use conv4
    scores = zeros(ave_per_image_topN_conv6*length(sample_aboxes), 1);
    for i = 1:length(sample_aboxes)
        s_scores = sort([scores; sample_aboxes{i}(:, end)], 'descend');
        scores = s_scores(1:ave_per_image_topN_conv6*length(sample_aboxes));
    end
    score_thresh_conv6 = scores(end);
    
    fprintf('score_threshold conv4 = %f, conv5 = %f, conv6 = %f\n', score_thresh_conv4, score_thresh_conv5, score_thresh_conv6);
    
    % 1122 added to save combined results of conv4, conv5 and conv6
    aboxes = cell(length(aboxes_conv4), 1);  % conv5 and conv6 are also ok
    % eval the gt recall
    gt_num = 0;
    gt_re_num_5 = 0;
    gt_re_num_7 = 0;
    gt_re_num_8 = 0;
    gt_re_num_9 = 0;
    for i = 1:length(roidb.rois)
        %aboxes{i} = cat(1, aboxes_conv4{i}, aboxes_conv5{i}, aboxes_conv6{i});
        aboxes{i} = cat(1, aboxes_conv4{i}(aboxes_conv4{i}(:, end) > score_thresh_conv4, :),...
                           aboxes_conv5{i}(aboxes_conv5{i}(:, end) > score_thresh_conv5, :),...
                           aboxes_conv6{i}(aboxes_conv6{i}(:, end) > score_thresh_conv6, :));
        %gts = roidb.rois(i).boxes(roidb.rois(i).ignores~=1, :);
        gts = roidb.rois(i).boxes;
        if ~isempty(gts)
            gt_num = gt_num + size(gts, 1);
            if ~isempty(aboxes{i})
                rois = aboxes{i}(:, 1:4);
                max_ols = max(boxoverlap(rois, gts));
                gt_re_num_5 = gt_re_num_5 + sum(max_ols >= 0.5);
                gt_re_num_7 = gt_re_num_7 + sum(max_ols >= 0.7);
                gt_re_num_8 = gt_re_num_8 + sum(max_ols >= 0.8);
                gt_re_num_9 = gt_re_num_9 + sum(max_ols >= 0.9);
            end
        end
    end
    fprintf('gt recall rate (ol >0.5) = %.4f\n', gt_re_num_5 / gt_num);
    fprintf('gt recall rate (ol >0.7) = %.4f\n', gt_re_num_7 / gt_num);
    fprintf('gt recall rate (ol >0.8) = %.4f\n', gt_re_num_8 / gt_num);
    fprintf('gt recall rate (ol >0.9) = %.4f\n', gt_re_num_9 / gt_num);

    roidb_regions.boxes = aboxes;
    roidb_regions.images = imdb.image_ids;
    % concatenate gt boxes and high-scoring dt boxes
    roidb_BF                   = roidb_from_proposal_score(imdb, roidb, roidb_regions, ...
            'keep_raw_proposal', false);
        
    save(save_roidb_name, 'roidb_BF', '-v7.3');
end

function aboxes = boxes_filter(aboxes, per_nms_topN, nms_overlap_thres, after_nms_topN, use_gpu)
    % to speed up nms
    % liu@1001: get the first per_nms_topN bboxes
    % it is no good to get per_nms_topN samples from each image since some
    % images have more hard samples which should be sampled more while others contain very 
    % easy samples which should be sampled less
    if per_nms_topN > 0
        aboxes = cellfun(@(x) x(1:min(size(x, 1), per_nms_topN), :), aboxes, 'UniformOutput', false);
    end
    % do nms
    if nms_overlap_thres > 0 && nms_overlap_thres < 1  
        if use_gpu
            for i = 1:length(aboxes)
                tic_toc_print('nms: %d / %d \n', i, length(aboxes));
                aboxes{i} = aboxes{i}(nms(aboxes{i}, nms_overlap_thres, use_gpu), :);
            end
        else
            parfor i = 1:length(aboxes)
                aboxes{i} = aboxes{i}(nms(aboxes{i}, nms_overlap_thres), :);
            end
        end
    end
    if after_nms_topN > 0
        aboxes = cellfun(@(x) x(1:min(size(x, 1), after_nms_topN), :), aboxes, 'UniformOutput', false);
    end
end

