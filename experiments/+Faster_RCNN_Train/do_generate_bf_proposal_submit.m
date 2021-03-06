function roidb_BF = do_generate_bf_proposal_submit(conf, model_stage, imdb, roidb, is_test)
    
    cache_dir = fullfile(pwd, 'output', conf.exp_name, 'rpn_cachedir', model_stage.cache_name, imdb.name);
    %cache_dir = fullfile(pwd, 'output', model_stage.cache_name, imdb.name);
    save_roidb_name = fullfile(cache_dir, [ 'roidb_' imdb.name '_BF_submit.mat']);
    if exist(save_roidb_name, 'file')
        ld = load(save_roidb_name);
        roidb_BF = ld.roidb_BF;
        clear ld;
        return;
    end
    
    aboxes                      = proposal_test_widerface(conf, imdb, ...
                                        'net_def_file',     model_stage.test_net_def_file, ...
                                        'net_file',         model_stage.output_model_file, ...
                                        'cache_name',       model_stage.cache_name,...
                                        'suffix',           '_submit'); 
                               
    fprintf('Doing nms ... ');   
    % liu@1001: model_stage.nms.after_nms_topN functions as a threshold, indicating how many boxes will be preserved on average
    ave_per_image_topN = model_stage.nms.after_nms_topN;
    model_stage.nms.after_nms_topN = -1;
    aboxes                      = boxes_filter(aboxes, model_stage.nms.per_nms_topN, model_stage.nms.nms_overlap_thres, model_stage.nms.after_nms_topN, conf.use_gpu);      
    fprintf(' Done.\n');  
    
    % only use the first max_sample_num images to compute an "expected" lower bound thresh
    max_sample_num = 5000;
    sample_aboxes = aboxes(randperm(length(aboxes), min(length(aboxes), max_sample_num)));
    scores = zeros(ave_per_image_topN*length(sample_aboxes), 1);
    for i = 1:length(sample_aboxes)
        s_scores = sort([scores; sample_aboxes{i}(:, end)], 'descend');
        scores = s_scores(1:ave_per_image_topN*length(sample_aboxes));
    end
    score_thresh = scores(end);
    fprintf('score_threshold:%f\n', score_thresh);
    % drop the boxes which scores are lower than the threshold
    nms_option = 0; %0(no_nms),1,2,3
    for i = 1:length(aboxes)
        aboxes{i} = aboxes{i}(aboxes{i}(:, end) > score_thresh, :);
        % do NMS
        %aboxes{i} = pseudoNMS(aboxes{i});
        %aboxes{i} = pseudoNMS_v2(aboxes{i}, nms_option);
        aboxes{i} = pseudoNMS_v3(aboxes{i}, nms_option);
    end
    
    % ########## save the raw result (before BF) here #############
%     if is_test
%         fid = fopen(fullfile(cache_dir, sprintf('VGG16_e1-e3-RPN-keep-ave-%d-nms-op%d.txt',ave_per_image_topN, nms_option)), 'a');
%         %fid = fopen(fullfile(cache_dir, 'ZF_e1-e3-RPN_11.txt'), 'a');
% 
%         assert(length(imdb.image_ids) == size(aboxes, 1));
%         for i = 1:size(aboxes, 1)
%             if ~isempty(aboxes{i})
%                 sstr = strsplit(imdb.image_ids{i}, filesep);
%                 % [x1 y1 x2 y2] pascal VOC style
%                 for j = 1:size(aboxes{i}, 1)
%                     %each row: [image_name score x1 y1 x2 y2]
%                     fprintf(fid, '%s %f %d %d %d %d\n', sstr{2}, aboxes{i}(j, 5), round(aboxes{i}(j, 1:4)));
%                 end
%             end
%         end
%         fclose(fid);
%         fprintf('Done with saving RPN detected boxes.\n');
%     end
    
    % eval the gt recall
    gt_num = 0;
    gt_re_num_5 = 0;
    gt_re_num_7 = 0;
    gt_re_num_8 = 0;
    gt_re_num_9 = 0;
    for i = 1:length(roidb.rois)
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

