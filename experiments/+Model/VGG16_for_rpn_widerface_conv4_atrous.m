function model = VGG16_for_rpn_widerface_conv4_atrous(exp_name, model)


model.mean_image                                = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'mean_image');
model.pre_trained_net_file                      = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'vgg16.caffemodel');
% Stride in input image pixels at the last conv layer
model.feat_stride                               = 8; %16

%% stage 1 rpn, inited from pre-trained network
% solver_60k80k_widerface_conv4_atrous.prototxt
model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_16layers_atrous', 'solver_60k80k_widerface_conv4_atrous_reduce3.prototxt'); 
% test_widerface_conv4_atrous.prototxt
model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_16layers_atrous', 'test_widerface_conv4_atrous_reduce3.prototxt');
model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;

% rpn test setting
model.stage1_rpn.nms.per_nms_topN               = -1; %20000
model.stage1_rpn.nms.nms_overlap_thres       	= 1;%0.7
model.stage1_rpn.nms.after_nms_topN         	= 500;  %1000

end