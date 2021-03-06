function script_rpn_face_VGG16_widerface_conv3_4_batch2()
% script_rpn_face_VGG16_widerface_conv3()
% --------------------------------------------------------
% 1204 created by Yuguang Liu
% --------------------------------------------------------

% ********** liu@1001: run this at root directory !!! *******************************

clc;
clear mex;
clear is_valid_handle; % to clear init_key
run(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'startup'));
%% -------------------- CONFIG --------------------
%0930 change caffe folder according to platform
if ispc
    opts.caffe_version          = 'caffe_faster_rcnn_win_cudnn_final'; %'caffe_faster_rcnn_win_cudnn'
    cd('D:\\RPN_BF_master');
elseif isunix
    opts.caffe_version          = 'caffe_faster_rcnn_dilate_ohem'; %'caffe_faster_rcnn_rfcn_ohem_final_noprint';
    cd('/usr/local/data/yuguang/git_all/RPN_BF_pedestrain/RPN_BF-RPN-pedestrian');
end
opts.gpu_id                 = auto_select_gpu;
active_caffe_mex(opts.gpu_id, opts.caffe_version);
% use bbapply to draw boxes in 'proposal test widerface conv3_4'
addpath(genpath(fullfile('external','toolbox')));  % piotr's image and video toolbox
% 1009 use more anchors
exp_name = 'VGG16_widerface';

% do validation, or not 
opts.do_val                 = true; 
% model
model                       = Model.VGG16_for_rpn_widerface_conv3_4_batch2(exp_name);
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
model_name_base = 'vgg16_conv3_4';  % ZF, vgg16_conv5
%1009 change exp here for output
exp_name = 'VGG16_widerface_conv3_4_batch2';
% the dir holding intermediate data paticular
cache_data_this_model_dir = fullfile(cache_data_root, exp_name, 'rpn_cachedir');
mkdir_if_missing(cache_data_this_model_dir);
use_flipped                 = false;  %true --> false
event_num                   = 11; %3
dataset                     = Dataset.widerface_all_512(dataset, 'train', use_flipped, event_num, cache_data_this_model_dir, model_name_base);
dataset                     = Dataset.widerface_all_512(dataset, 'test', false, event_num, cache_data_this_model_dir, model_name_base);

%0805 added, make sure imdb_train and roidb_train are of cell type
if ~iscell(dataset.imdb_train)
    dataset.imdb_train = {dataset.imdb_train};
end
if ~iscell(dataset.roidb_train)
    dataset.roidb_train = {dataset.roidb_train};
end

% %% -------------------- TRAIN --------------------
% conf
conf_proposal               = proposal_config_widerface_batch2('image_means', model.mean_image, 'feat_stride', model.feat_stride);
%conf_fast_rcnn              = fast_rcnn_config_widerface('image_means', model.mean_image);
% generate anchors and pre-calculate output size of rpn network 

conf_proposal.exp_name = exp_name;
%conf_fast_rcnn.exp_name = exp_name;
%[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
%                            = proposal_prepare_anchors(conf_proposal, model.stage1_rpn.cache_name, model.stage1_rpn.test_net_def_file);
% ###4/5### CHANGE EACH TIME*** : name of output map
output_map_name = 'output_map_64_3008';  % output_map_512
output_map_save_name = fullfile(cache_data_this_model_dir, output_map_name);
[conf_proposal.output_width_map, conf_proposal.output_height_map] = proposal_calc_output_size_512(conf_proposal, ...
                                                                    model.stage1_rpn.test_net_def_file, output_map_save_name);
%conf_proposal.anchors = proposal_generate_anchors(cache_data_this_model_dir, 'ratios', [1], 'scales',  2.^[-1:1]);  %[8 16 32]
conf_proposal.anchors = proposal_generate_anchors_CMS(cache_data_this_model_dir, ...
                         'ratios', [1], 'scales',  2.^[-1:4], 'add_size', [480]);  %[8 16 32 64 128 256 480]
%1009: from 7 to 12 anchors
%1012: from 12 to 24 anchors
%conf_proposal.anchors = proposal_generate_24anchors(cache_data_this_model_dir, 'scales', [10 16 24 32 48 64 90 128 180 256 360 512 720]);
        
%%  train
fprintf('\n***************\nstage one RPN \n***************\n');
model.stage1_rpn            = Faster_RCNN_Train.do_proposal_train_widerface_conv3_4_batch2(conf_proposal, dataset, model.stage1_rpn, opts.do_val);

%% test
nms_option_test = 3;
%0112: here use all val set for evaluation
event_num = -1;%11:512 size, -1: ori size
dataset                     = Dataset.widerface_all(dataset, 'test', false, event_num, cache_data_this_model_dir, model_name_base);
Faster_RCNN_Train.do_proposal_test_widerface_conv3_4(conf_proposal, model.stage1_rpn, dataset.imdb_test, dataset.roidb_test, nms_option_test);
end
