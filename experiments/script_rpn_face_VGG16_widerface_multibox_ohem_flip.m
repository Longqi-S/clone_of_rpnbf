function script_rpn_face_VGG16_widerface_multibox_ohem_flip()
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
    opts.caffe_version          = 'caffe_faster_rcnn_win_cudnn'; %caffe_faster_rcnn_win
    cd('D:\\RPN_BF_master');
elseif isunix
    % caffe_faster_rcnn_rfcn is from caffe-rfcn-r-fcn_othersoft
    % caffe_faster_rcnn_rfcn_normlayer is also from
    % caffe-rfcn-r-fcn_othersoft with l2-normalization layer added
    opts.caffe_version          = 'caffe_faster_rcnn_rfcn_ohem_final_noprint'; %'caffe_faster_rcnn_rfcn_normlayer'
    cd('/usr/local/data/yuguang/git_all/RPN_BF_pedestrain/RPN_BF-RPN-pedestrian');
end
opts.gpu_id                 = auto_select_gpu;
active_caffe_mex(opts.gpu_id, opts.caffe_version);

% 1009 use more anchors
exp_name = 'VGG16_widerface';

% do validation, or not 
opts.do_val                 = true; 
% model
model                       = Model.VGG16_for_rpn_widerface_multibox_ohem_flip(exp_name);
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
model_name_base = 'vgg16_multibox';  % ZF, vgg16_conv5
%1009 change exp here for output
exp_name = 'VGG16_widerface_multibox_ohem_flip';
% the dir holding intermediate data paticular
cache_data_this_model_dir = fullfile(cache_data_root, exp_name, 'rpn_cachedir');
mkdir_if_missing(cache_data_this_model_dir);
use_flipped                 = true;  %true --> false
event_num                   = 11; %-1
dataset                     = Dataset.widerface_all_flip(dataset, 'train', use_flipped, event_num, cache_data_this_model_dir, model_name_base);
dataset                     = Dataset.widerface_all(dataset, 'test', false, event_num, cache_data_this_model_dir, model_name_base);

%0805 added, make sure imdb_train and roidb_train are of cell type
if ~iscell(dataset.imdb_train)
    dataset.imdb_train = {dataset.imdb_train};
end
if ~iscell(dataset.roidb_train)
    dataset.roidb_train = {dataset.roidb_train};
end

% %% -------------------- TRAIN --------------------
% conf
conf_proposal               = proposal_config_widerface_multibox_ohem('image_means', model.mean_image, ...
                                                    'feat_stride_conv4', model.feat_stride_conv4, ...
                                                    'feat_stride_conv5', model.feat_stride_conv5, ...
                                                    'feat_stride_conv6', model.feat_stride_conv6 );
%conf_fast_rcnn              = fast_rcnn_config_widerface('image_means', model.mean_image);
% generate anchors and pre-calculate output size of rpn network 

conf_proposal.exp_name = exp_name;
%conf_fast_rcnn.exp_name = exp_name;
%[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
%                            = proposal_prepare_anchors(conf_proposal, model.stage1_rpn.cache_name, model.stage1_rpn.test_net_def_file);
% ###4/5### CHANGE EACH TIME*** : name of output map
output_map_name = 'output_map_multibox';  % output_map_conv4, output_map_conv5
output_map_save_name = fullfile(cache_data_this_model_dir, output_map_name);
[conf_proposal.output_width_conv4, conf_proposal.output_height_conv4, ...
 conf_proposal.output_width_conv5, conf_proposal.output_height_conv5, ...
 conf_proposal.output_width_conv6, conf_proposal.output_height_conv6]...
                             = proposal_calc_output_size_multibox_final3(conf_proposal, model.stage1_rpn.test_net_def_file, output_map_save_name);
[conf_proposal.anchors_conv4,conf_proposal.anchors_conv5, conf_proposal.anchors_conv6] = proposal_generate_anchors_multibox_ohem_flip(cache_data_this_model_dir, ...
                                                            'ratios', [1.25 0.8], 'scales',  2.^[-1:5], 'add_size', [360 720 900]);  %[8 16 32 64 128 256 360 512 720 900]
%1009: from 7 to 12 anchors
%1012: from 12 to 24 anchors
%conf_proposal.anchors = proposal_generate_24anchors(cache_data_this_model_dir, 'scales', [10 16 24 32 48 64 90 128 180 256 360 512 720]);
        
%%  train
fprintf('\n***************\nstage one RPN \n***************\n');
model.stage1_rpn            = Faster_RCNN_Train.do_proposal_train_widerface_multibox_ohem(conf_proposal, dataset, model.stage1_rpn, opts.do_val);

%% test
cache_name = 'widerface';
method_name = 'RPN-ped';
nms_option_test = 3;
Faster_RCNN_Train.do_proposal_test_widerface_multibox_ohem_flip(conf_proposal, model.stage1_rpn, dataset.imdb_test, dataset.roidb_test, cache_name, method_name, nms_option_test);

end