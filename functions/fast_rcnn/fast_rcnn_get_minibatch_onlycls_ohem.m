function [im_blob, rois_blob, labels_blob] = fast_rcnn_get_minibatch_onlycls_ohem(conf, image_roidb)
% [im_blob, rois_blob, labels_blob, bbox_targets_blob, bbox_loss_blob] ...
%    = fast_rcnn_get_minibatch(conf, image_roidb)
% --------------------------------------------------------
% Fast R-CNN
% Reimplementation based on Python Fast R-CNN (https://github.com/rbgirshick/fast-rcnn)
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

    num_images = length(image_roidb);
    % Infer number of classes from the number of columns in gt_overlaps
    num_classes = size(image_roidb(1).overlap, 2);
    % Sample random scales to use for each image in this batch
    random_scale_inds = randi(length(conf.scales), num_images, 1);
    
    assert(mod(conf.batch_size, num_images) == 0, ...
        sprintf('num_images %d must divide BATCH_SIZE %d', num_images, conf.batch_size));
    
    rois_per_image = conf.batch_size / num_images;
    fg_rois_per_image = round(rois_per_image * conf.fg_fraction);
    
    % Get the input image blob
    [im_blob, im_scales] = get_image_blob(conf, image_roidb, random_scale_inds);
    
    % build the region of interest and label blobs
    rois_blob = zeros(0, 5, 'single');
    labels_blob = zeros(0, 1, 'single');
    
    for i = 1:num_images
        [labels, ~, im_rois] = ...
            sample_rois(conf, image_roidb(i), fg_rois_per_image, rois_per_image);
        
        % Add to ROIs blob
        %1207: extend to [left, top, right, bottom] = [-0.5 -0.2 0.5 0.8]
        feat_rois = fast_rcnn_map_im_rois_to_feat_rois(conf, im_rois, im_scales(i), image_roidb(i).im_size);
        %feat_rois = fast_rcnn_map_im_rois_to_feat_rois(conf, im_rois, im_scales(i));
        batch_ind = i * ones(size(feat_rois, 1), 1);
        rois_blob_this_image = [batch_ind, feat_rois];
        rois_blob = [rois_blob; rois_blob_this_image];
        
        % Add to labels, bbox targets, and bbox loss blobs
        labels_blob = [labels_blob; labels];
    end
    
    % permute data into caffe c++ memory, thus [num, channels, height, width]
    im_blob = im_blob(:, :, [3, 2, 1], :); % from rgb to brg
    im_blob = single(permute(im_blob, [2, 1, 3, 4]));
    rois_blob = rois_blob - 1; % to c's index (start from 0)
    rois_blob = single(permute(rois_blob, [3, 4, 2, 1]));
    labels_blob = single(permute(labels_blob, [3, 4, 2, 1]));
    
    assert(~isempty(im_blob));
    assert(~isempty(rois_blob));
    assert(~isempty(labels_blob));
end

%% Build an input blob from the images in the roidb at the specified scales.
function [im_blob, im_scales] = get_image_blob(conf, images, random_scale_inds)
    
    num_images = length(images);
    processed_ims = cell(num_images, 1);
    im_scales = nan(num_images, 1);
    for i = 1:num_images
        im = imread(images(i).image_path);
        target_size = conf.scales(random_scale_inds(i));
        
        [im, im_scale] = prep_im_for_blob(im, conf.image_means, target_size, conf.max_size);
        
        im_scales(i) = im_scale;
        processed_ims{i} = im; 
    end
    
    im_blob = im_list_to_blob(processed_ims);
end

%% Generate a random sample of ROIs comprising foreground and background examples.
function [labels, overlaps, rois] = ...
    sample_rois(conf, image_roidb, fg_rois_per_image, rois_per_image)

    [overlaps, labels] = max(image_roidb(1).overlap, [], 2);
%     labels = image_roidb(1).max_classes;
%     overlaps = image_roidb(1).max_overlaps;
    rois = image_roidb(1).boxes;
    
    % Select foreground ROIs as those with >= FG_THRESH overlap
    fg_inds = find(overlaps >= conf.fg_thresh);
    if length(fg_inds) > 50
        fg_inds = fg_inds(randperm(length(fg_inds), 50));
    end
    % Guard against the case when an image has fewer than fg_rois_per_image
    % foreground ROIs
%     fg_rois_per_this_image = min(fg_rois_per_image, length(fg_inds));
%     % Sample foreground regions without replacement
%     if ~isempty(fg_inds)
%        fg_inds = fg_inds(randperm(length(fg_inds), fg_rois_per_this_image));
%     end
    
    % Select background ROIs as those within [BG_THRESH_LO, BG_THRESH_HI)
    bg_inds = find(overlaps < conf.bg_thresh_hi & overlaps >= conf.bg_thresh_lo);
    if length(bg_inds) > 250
        bg_inds = bg_inds(randperm(length(bg_inds), 250));
    end
    % Compute number of background ROIs to take from this image (guarding
    % against there being fewer than desired)
%     bg_rois_per_this_image = rois_per_image - fg_rois_per_this_image;
%     bg_rois_per_this_image = min(bg_rois_per_this_image, length(bg_inds));
%     % Sample foreground regions without replacement
%     if ~isempty(bg_inds)
%        bg_inds = bg_inds(randperm(length(bg_inds), bg_rois_per_this_image));
%     end
    % The indices that we're selecting (both fg and bg)
    keep_inds = [fg_inds; bg_inds];
    % Select sampled values from various arrays
    labels = labels(keep_inds);
    % Clamp labels for the background ROIs to 0
    % 1207 changed: to match the above change
    %labels((fg_rois_per_this_image+1):end) = 0;
    labels((length(fg_inds)+1):end) = 0;
    overlaps = overlaps(keep_inds);
    rois = rois(keep_inds, :);
    
    assert(all(labels == image_roidb.bbox_targets(keep_inds, 1)));
end
