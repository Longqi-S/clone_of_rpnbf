function script_VGG16_widerface_multibox_ohem_ablation()
% script_rpn_face_VGG16_widerface_multibox_ohem()
% --------------------------------------------------------
% Yuguang Liu
% 3 layers of loss output
% --------------------------------------------------------

% ********** liu@1001: run this at root directory !!! *******************************

clc;
clear mex;
clear is_valid_handle; % to clear init_key
run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'startup'));
%% -------------------- CONFIG --------------------
%0930 change caffe folder according to platform
if ispc
    opts.caffe_version          = 'caffe_rfcn_win_multibox_ohem'; %'caffe_faster_rcnn_win_cudnn'
    cd('D:\\RPN_BF_master');
elseif isunix
    % caffe_faster_rcnn_rfcn is from caffe-rfcn-r-fcn_othersoft
    % caffe_faster_rcnn_rfcn_normlayer is also from
    % caffe-rfcn-r-fcn_othersoft with l2-normalization layer added
    opts.caffe_version          = 'caffe_faster_rcnn_dilate_ohem'; %'caffe_faster_rcnn_rfcn_ohem_final_noprint';
    cd('/usr/local/data/yuguang/git_all/RPN_BF_pedestrain/RPN_BF-RPN-pedestrian');
end
opts.gpu_id                 = auto_select_gpu;
active_caffe_mex(opts.gpu_id, opts.caffe_version);

% 1009 use more anchors
exp_name = 'VGG16_widerface';

% do validation, or not 
opts.do_val                 = true; 
% model
model                       = Model.VGG16_for_rpn_widerface_multibox_ohem_ablation(exp_name);
% cache base
cache_base_proposal         = 'rpn_widerface_VGG16';
%cache_base_fast_rcnn        = '';
% set cache folder for each stage
%model                       = Faster_RCNN_Train.set_cache_folder_widerface(cache_base_proposal,cache_base_fast_rcnn, model);
model                       = Faster_RCNN_Train.set_cache_folder_widerface(cache_base_proposal, model);
% train/test data
dataset                     = [];
% the root directory to hold any useful intermediate data during training process
cache_data_root = 'output';  %cache_data
mkdir_if_missing(cache_data_root);
% ###3/5### CHANGE EACH TIME*** use this to name intermediate data's mat files
model_name_base = 'VGG16_multibox_ablation';  % ZF, vgg16_conv5
%1009 change exp here for output
exp_name = 'VGG16_widerface_multibox_ohem_ablation_compare';
% the dir holding intermediate data paticular
cache_data_this_model_dir = fullfile(cache_data_root, exp_name, 'rpn_cachedir');
mkdir_if_missing(cache_data_this_model_dir);
use_flipped                 = false;  %true --> false
% 0127: in vn7 only use 11 event for demo
train_event_pool            = [1 61 3 5 6 9 11 12 14 33 37 38 45 51 56]; %-1
dataset                     = Dataset.widerface_ablation_512(dataset, 'train', use_flipped, train_event_pool, cache_data_this_model_dir, model_name_base);
%dataset                     = Dataset.widerface_all(dataset, 'test', false, event_num, cache_data_this_model_dir, model_name_base);
%0106 added all test images
test_event_pool             = 1:61;
dataset                     = Dataset.widerface_ablation_512(dataset, 'test', false, test_event_pool, cache_data_this_model_dir, model_name_base);
% 0206 added: adapt dataset created in puck to VN7
if ispc
    devkit = 'D:\\datasets\\WIDERFACE';
    %train
    dataset.imdb_train.image_dir = fullfile(devkit, 'WIDER_train_ablation', 'images');
    dataset.imdb_train.image_ids = cellfun(@(x) strrep(x,'/',filesep), dataset.imdb_train.image_ids, 'UniformOutput', false);
    dataset.imdb_train.image_at = @(i) sprintf('%s%c%s.%s', dataset.imdb_train.image_dir, filesep, dataset.imdb_train.image_ids{i}, dataset.imdb_train.extension);
    %val
    dataset.imdb_test.image_dir = fullfile(devkit, 'WIDER_val_ablation', 'images');
    dataset.imdb_test.image_ids = cellfun(@(x) strrep(x,'/',filesep), dataset.imdb_test.image_ids, 'UniformOutput', false);
    dataset.imdb_test.image_at = @(i) sprintf('%s%c%s.%s', dataset.imdb_test.image_dir, filesep, dataset.imdb_test.image_ids{i}, dataset.imdb_test.extension);
    %verify
    if 0
        %---train-----------
        im = imread(dataset.imdb_train.image_at(666));
        figure(1),imshow(im)
        box = dataset.roidb_train.rois(666).boxes;
        box(:,3) = box(:,3) - box(:,1) +1;
        box(:,4) = box(:,4) - box(:,2) +1;
        bbApply('draw', box, 'm');
        %----test---------
        im = imread(dataset.imdb_test.image_at(666));
        figure(2),imshow(im)
        box = dataset.roidb_test.rois(666).boxes;
        box(:,3) = box(:,3) - box(:,1) +1;
        box(:,4) = box(:,4) - box(:,2) +1;
        bbApply('draw', box, 'm');
    end
end
%0805 added, make sure imdb_train and roidb_train are of cell type
if ~iscell(dataset.imdb_train)
    dataset.imdb_train = {dataset.imdb_train};
end
if ~iscell(dataset.roidb_train)
    dataset.roidb_train = {dataset.roidb_train};
end

% %% -------------------- TRAIN --------------------
% conf
conf_proposal               = proposal_config_widerface_multibox_ohem_ablation('image_means', model.mean_image, ...
                                                    'feat_stride_s4', model.feat_stride_s4, ...
                                                    'feat_stride_s8', model.feat_stride_s8, ...
                                                    'feat_stride_s16', model.feat_stride_s16 );
%conf_fast_rcnn              = fast_rcnn_config_widerface('image_means', model.mean_image);
% generate anchors and pre-calculate output size of rpn network 

conf_proposal.exp_name = exp_name;
%conf_fast_rcnn.exp_name = exp_name;
%[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
%                            = proposal_prepare_anchors(conf_proposal, model.stage1_rpn.cache_name, model.stage1_rpn.test_net_def_file);
% ###4/5### CHANGE EACH TIME*** : name of output map
output_map_name = 'output_map_multibox_ohem_happy';  % output_map_conv4, output_map_conv5
output_map_save_name = fullfile(cache_data_this_model_dir, output_map_name);
[conf_proposal.output_width_s4, conf_proposal.output_height_s4, ...
 conf_proposal.output_width_s8, conf_proposal.output_height_s8, ...
 conf_proposal.output_width_s16, conf_proposal.output_height_s16]...
                             = proposal_calc_output_size_multibox_ablation(conf_proposal, model.stage1_rpn.test_net_def_file, output_map_save_name);
% 1209: no need to change: same with all multibox
[conf_proposal.anchors_s4,conf_proposal.anchors_s8, conf_proposal.anchors_s16] = proposal_generate_anchors_multibox_CRV(cache_data_this_model_dir, ...
                                                            'ratios', [1], 'scales',  2.^[-1:5], 'add_size', [360 720 900]);  %[8 16 32 64 128 256 360 512 720 900]

%%  train
fprintf('\n***************\nstage one RPN \n***************\n');
model.stage1_rpn            = Faster_RCNN_Train.do_proposal_train_widerface_multibox_ohem_ablation(conf_proposal, dataset, model.stage1_rpn, opts.do_val);

% 1020: currently do not consider test
nms_option_test = 3;
% 0129: use full-size validation images instead of 512x512
Faster_RCNN_Train.do_proposal_test_widerface_multibox_ohem_ablation(conf_proposal, model.stage1_rpn, dataset.imdb_test, dataset.roidb_test, nms_option_test);

end
