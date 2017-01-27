function model = VGG16_for_rpn_widerface_conv3_4_batch2_fastrcnn(exp_name, model)


model.mean_image                                = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'mean_image');
model.pre_trained_net_file                      = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'vgg16.caffemodel');
% Stride in input image pixels at the last conv layer
model.feat_stride                               = 8; %4

% stage 1 rpn, inited from pre-trained network
model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_16layers_conv3_final', 'solver_60k80k_widerface_conv3_4_batch2.prototxt'); 
model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_16layers_conv3_final', 'test_widerface_conv3_4_batch2.prototxt');
model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;

% rpn test setting
model.stage1_rpn.nms.per_nms_topN               = -1; %20000
model.stage1_rpn.nms.nms_overlap_thres       	= 0.7;%0124:1--> 0.7
model.stage1_rpn.nms.after_nms_topN         	= 100;%0124:300->100

%stage 1 fast rcnn, inited from stage 1 rpn
model.stage1_fast_rcnn.solver_def_file          = fullfile(pwd, 'models', exp_name,'rpn_prototxts', 'vgg_16layers_conv3_final', 'solver_60k80k_stage2_conv3_4.prototxt');
model.stage1_fast_rcnn.test_net_def_file        = fullfile(pwd, 'models', exp_name,'rpn_prototxts', 'vgg_16layers_conv3_final', 'test_stage2_conv3_4.prototxt');
end