function [input_blobs, random_scale_inds] = proposal_generate_minibatch_ablation_batchmulti_noohem(conf, image_roidb)
% [input_blobs, random_scale_inds] = proposal_generate_minibatch(conf, image_roidb)
% --------------------------------------------------------
% Faster R-CNN
% Copyright (c) 2015, Shaoqing Ren
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------
    %debug_flag = true;
    % ========add random seed=======
%     if debug_flag
%         rng_seed = 6;
%         prev_rng = rng;
%         rng(rng_seed, 'twister');
%     end
    % =============================
    num_images = length(image_roidb);
    %%0225 masked
    %assert(num_images == 1, 'proposal_generate_minibatch_fcn only support num_images == 1');

    % Sample random scales to use for each image in this batch
    random_scale_inds = randi(length(conf.scales), num_images, 1);

    assert(mod(conf.batch_size, num_images) == 0, ...
        sprintf('num_images %d must divide BATCH_SIZE %d', num_images, conf.batch_size));
    
    rois_per_image = conf.batch_size / num_images;
    fg_rois_per_image = round(rois_per_image * conf.fg_fraction);
    
    % Get the input image blob
    [im_blob, im_scales] = get_image_blob(conf, image_roidb, random_scale_inds);
    
    %0122 added: initialize labels and weights for 2 images
    %s4
    feat_hei_s4 = cell2mat(conf.output_height_s4.values({size(im_blob,1)}));
    feat_wid_s4 = cell2mat(conf.output_width_s4.values({size(im_blob,2)}));
    feat_chl_s4 = size(conf.anchors_s4, 1);
    labels_blob_conv4 = zeros(feat_wid_s4, feat_hei_s4, feat_chl_s4, num_images);
    label_weights_blob_conv4 = labels_blob_conv4;
    bbox_targets_blob_conv4 = zeros(feat_wid_s4, feat_hei_s4, feat_chl_s4*4, num_images);
    bbox_loss_blob_conv4 = bbox_targets_blob_conv4;
    %s8
    feat_hei_s8 = cell2mat(conf.output_height_s8.values({size(im_blob,1)}));
    feat_wid_s8 = cell2mat(conf.output_width_s8.values({size(im_blob,2)}));
    feat_chl_s8 = size(conf.anchors_s8, 1);
    labels_blob_conv5 = zeros(feat_wid_s8, feat_hei_s8, feat_chl_s8, num_images);
    label_weights_blob_conv5 = labels_blob_conv5;
    bbox_targets_blob_conv5 = zeros(feat_wid_s8, feat_hei_s8, feat_chl_s8*4, num_images);
    bbox_loss_blob_conv5 = bbox_targets_blob_conv5;
    %s16
    feat_hei_s16 = cell2mat(conf.output_height_s16.values({size(im_blob,1)}));
    feat_wid_s16 = cell2mat(conf.output_width_s16.values({size(im_blob,2)}));
    feat_chl_s16 = size(conf.anchors_s16, 1);
    labels_blob_conv6 = zeros(feat_wid_s16, feat_hei_s16, feat_chl_s16, num_images);
    label_weights_blob_conv6 = labels_blob_conv6;
    bbox_targets_blob_conv6 = zeros(feat_wid_s16, feat_hei_s16, feat_chl_s16*4, num_images);
    bbox_loss_blob_conv6 = bbox_targets_blob_conv6;
    
    for i = 1:num_images
        [labels_conv4, label_weights_conv4, bbox_targets_conv4, bbox_loss_conv4] = ...
            sample_rois(conf, image_roidb(i).bbox_targets_s4, fg_rois_per_image, rois_per_image, im_scales(i), random_scale_inds(i));
        [labels_conv5, label_weights_conv5, bbox_targets_conv5, bbox_loss_conv5] = ...
            sample_rois(conf, image_roidb(i).bbox_targets_s8, fg_rois_per_image, rois_per_image, im_scales(i), random_scale_inds(i));
        [labels_conv6, label_weights_conv6, bbox_targets_conv6, bbox_loss_conv6] = ...
            sample_rois(conf, image_roidb(i).bbox_targets_s16, fg_rois_per_image, rois_per_image, im_scales(i), random_scale_inds(i));
        
        % get fcn output size
        img_size = round(image_roidb(i).im_size * im_scales(i));
		%1206 added
        img_size = ceil(img_size/8)*8;
        assert(img_size(1) == size(im_blob, 1) && img_size(2) == size(im_blob, 2));
        
        % =============== for conv4 =================
        output_size_conv4 = cell2mat([conf.output_height_s4.values({img_size(1)}), conf.output_width_s4.values({img_size(2)})]);
        labels_blob_s4_tmp = reshape(labels_conv4, size(conf.anchors_s4, 1), output_size_conv4(1), output_size_conv4(2));
        label_weights_blob_s4_tmp = reshape(label_weights_conv4, size(conf.anchors_s4, 1), output_size_conv4(1), output_size_conv4(2));
        bbox_targets_blob_s4_tmp = reshape(bbox_targets_conv4', size(conf.anchors_s4, 1)*4, output_size_conv4(1), output_size_conv4(2));
        bbox_loss_blob_s4_tmp = reshape(bbox_loss_conv4', size(conf.anchors_s4, 1)*4, output_size_conv4(1), output_size_conv4(2));
        % permute from [channel, height, width], where channel is the
        % fastest dimension to [width, height, channel]
        labels_blob_conv4(:,:,:,i) = permute(labels_blob_s4_tmp, [3, 2, 1]);
        label_weights_blob_conv4(:,:,:,i) = permute(label_weights_blob_s4_tmp, [3, 2, 1]);
        bbox_targets_blob_conv4(:,:,:,i) = permute(bbox_targets_blob_s4_tmp, [3, 2, 1]);
        bbox_loss_blob_conv4(:,:,:,i) = permute(bbox_loss_blob_s4_tmp, [3, 2, 1]);
        
        % =============== for conv5 =================
        output_size_conv5 = cell2mat([conf.output_height_s8.values({img_size(1)}), conf.output_width_s8.values({img_size(2)})]);
        labels_blob_s8_tmp = reshape(labels_conv5, size(conf.anchors_s8, 1), output_size_conv5(1), output_size_conv5(2));
        label_weights_blob_s8_tmp = reshape(label_weights_conv5, size(conf.anchors_s8, 1), output_size_conv5(1), output_size_conv5(2));
        bbox_targets_blob_s8_tmp = reshape(bbox_targets_conv5', size(conf.anchors_s8, 1)*4, output_size_conv5(1), output_size_conv5(2));
        bbox_loss_blob_s8_tmp = reshape(bbox_loss_conv5', size(conf.anchors_s8, 1)*4, output_size_conv5(1), output_size_conv5(2));
        % permute from [channel, height, width], where channel is the
        % fastest dimension to [width, height, channel]
        labels_blob_conv5(:,:,:,i) = permute(labels_blob_s8_tmp, [3, 2, 1]);
        label_weights_blob_conv5(:,:,:,i) = permute(label_weights_blob_s8_tmp, [3, 2, 1]);
        bbox_targets_blob_conv5(:,:,:,i) = permute(bbox_targets_blob_s8_tmp, [3, 2, 1]);
        bbox_loss_blob_conv5(:,:,:,i) = permute(bbox_loss_blob_s8_tmp, [3, 2, 1]);
        
        % =============== for conv6 =================
        output_size_conv6 = cell2mat([conf.output_height_s16.values({img_size(1)}), conf.output_width_s16.values({img_size(2)})]);
        labels_blob_s16_tmp = reshape(labels_conv6, size(conf.anchors_s16, 1), output_size_conv6(1), output_size_conv6(2));
        label_weights_blob_s16_tmp = reshape(label_weights_conv6, size(conf.anchors_s16, 1), output_size_conv6(1), output_size_conv6(2));
        bbox_targets_blob_s16_tmp = reshape(bbox_targets_conv6', size(conf.anchors_s16, 1)*4, output_size_conv6(1), output_size_conv6(2));
        bbox_loss_blob_s16_tmp = reshape(bbox_loss_conv6', size(conf.anchors_s16, 1)*4, output_size_conv6(1), output_size_conv6(2));
        % permute from [channel, height, width], where channel is the
        % fastest dimension to [width, height, channel]
        labels_blob_conv6(:,:,:,i) = permute(labels_blob_s16_tmp, [3, 2, 1]);
        label_weights_blob_conv6(:,:,:,i) = permute(label_weights_blob_s16_tmp, [3, 2, 1]);
        bbox_targets_blob_conv6(:,:,:,i) = permute(bbox_targets_blob_s16_tmp, [3, 2, 1]);
        bbox_loss_blob_conv6(:,:,:,i) = permute(bbox_loss_blob_s16_tmp, [3, 2, 1]);
    end
    
    % permute data into caffe c++ memory, thus [num, channels, height, width]
    im_blob = im_blob(:, :, [3, 2, 1], :); % from rgb to brg
    im_blob = single(permute(im_blob, [2, 1, 3, 4]));
    
    % ======conv4 =============
    labels_blob_conv4 = single(labels_blob_conv4);
    labels_blob_conv4(labels_blob_conv4 > 0) = 1; %to binary lable (fg and bg)
    label_weights_blob_conv4 = single(label_weights_blob_conv4);
    bbox_targets_blob_conv4 = single(bbox_targets_blob_conv4); 
    bbox_loss_blob_conv4 = single(bbox_loss_blob_conv4);
    % ======conv5 =============
    labels_blob_conv5 = single(labels_blob_conv5);
    labels_blob_conv5(labels_blob_conv5 > 0) = 1; %to binary lable (fg and bg)
    label_weights_blob_conv5 = single(label_weights_blob_conv5);
    bbox_targets_blob_conv5 = single(bbox_targets_blob_conv5); 
    bbox_loss_blob_conv5 = single(bbox_loss_blob_conv5);
    % ======conv6 =============
    labels_blob_conv6 = single(labels_blob_conv6);
    labels_blob_conv6(labels_blob_conv6 > 0) = 1; %to binary lable (fg and bg)
    label_weights_blob_conv6 = single(label_weights_blob_conv6);
    bbox_targets_blob_conv6 = single(bbox_targets_blob_conv6); 
    bbox_loss_blob_conv6 = single(bbox_loss_blob_conv6);
    
    assert(~isempty(im_blob));
    assert(~isempty(labels_blob_conv4));
    assert(~isempty(label_weights_blob_conv4));
    assert(~isempty(bbox_targets_blob_conv4));
    assert(~isempty(bbox_loss_blob_conv4));
    assert(~isempty(labels_blob_conv5));
    assert(~isempty(label_weights_blob_conv5));
    assert(~isempty(bbox_targets_blob_conv5));
    assert(~isempty(bbox_loss_blob_conv5));
    assert(~isempty(labels_blob_conv6));
    assert(~isempty(label_weights_blob_conv6));
    assert(~isempty(bbox_targets_blob_conv6));
    assert(~isempty(bbox_loss_blob_conv6));
    
    input_blobs = {im_blob, labels_blob_conv4, label_weights_blob_conv4, bbox_targets_blob_conv4, bbox_loss_blob_conv4, ...
                            labels_blob_conv5, label_weights_blob_conv5, bbox_targets_blob_conv5, bbox_loss_blob_conv5, ...
                            labels_blob_conv6, label_weights_blob_conv6, bbox_targets_blob_conv6, bbox_loss_blob_conv6};
    
    % ======= recover random seed=======
%     if debug_flag
%         rng(prev_rng);
%     end
    % =============================
end


%% Build an input blob from the images in the roidb at the specified scales.
function [im_blob, im_scales] = get_image_blob(conf, images, random_scale_inds)
    
    num_images = length(images);
    processed_ims = cell(num_images, 1);
    im_scales = nan(num_images, 1);
    for i = 1:num_images
        im = imread(images(i).image_path);
        target_size = conf.scales(random_scale_inds(i));
        % 1209: copy conv3plus4: pad image to 8N size
        [im, im_scale] = prep_im_for_blob_conv3plus4(im, conf.image_means, target_size, conf.max_size);
        
        im_scales(i) = im_scale;
        processed_ims{i} = im; 
    end
    
    im_blob = im_list_to_blob(processed_ims);
end

%% Generate a random sample of ROIs comprising foreground and background examples.
function [labels, label_weights, bbox_targets, bbox_loss_weights] = ...
    sample_rois(conf, image_roidb_bbox_targets, fg_rois_per_image, rois_per_image, im_scale, im_scale_ind)

    bbox_targets = image_roidb_bbox_targets{im_scale_ind};
    ex_asign_labels = bbox_targets(:, 1);
    
    % Select foreground ROIs as those with >= FG_THRESH overlap
    fg_inds = find(bbox_targets(:, 1) > 0);
    
    % Select background ROIs as those within [BG_THRESH_LO, BG_THRESH_HI)
    bg_inds = find(bbox_targets(:, 1) < 0);
    
    %1123 add ohem: all need to change is labels
    ohem_flag = false;
    if ohem_flag
        labels = -1 * ones(size(bbox_targets, 1), 1);
        % set foreground labels
        labels(fg_inds) = ex_asign_labels(fg_inds);
        assert(all(ex_asign_labels(fg_inds) > 0));
        % 1123: set background labels to 0
        labels(bg_inds) = 0;
    else
        % select foreground
        fg_num = min(fg_rois_per_image, length(fg_inds)); % 0
        fg_inds = fg_inds(randperm(length(fg_inds), fg_num));

        bg_num = min(rois_per_image - fg_num, length(bg_inds));
        bg_inds = bg_inds(randperm(length(bg_inds), bg_num));  %256

        labels = zeros(size(bbox_targets, 1), 1);
        % set foreground labels
        labels(fg_inds) = ex_asign_labels(fg_inds);
        assert(all(ex_asign_labels(fg_inds) > 0));
    end
    
    label_weights = zeros(size(bbox_targets, 1), 1);
    % set foreground labels weights
    label_weights(fg_inds) = 1;
    % set background labels weights
    label_weights(bg_inds) = conf.bg_weight;  %1123: 1 --> 0.5 (see config)
    
    bbox_targets = single(full(bbox_targets(:, 2:end)));
    
    bbox_loss_weights = bbox_targets * 0;
    bbox_loss_weights(fg_inds, :) = 1;
end

function visual_anchors(image_roidb, anchors, im_scale)
    imshow(imresize(imread(image_roidb.image_path), im_scale));
    hold on;
    cellfun(@(x) rectangle('Position', RectLTRB2LTWH(x), 'EdgeColor', 'r'), num2cell(anchors, 2));
    hold off;
end

