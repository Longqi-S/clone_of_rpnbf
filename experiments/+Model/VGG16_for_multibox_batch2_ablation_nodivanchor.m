function model = VGG16_for_multibox_batch2_ablation_nodivanchor(exp_name, model)


model.mean_image                                = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'mean_image');
model.pre_trained_net_file                      = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'vgg16.caffemodel');
% Stride in input image pixels at the last conv layer
%model.feat_stride                               = 16;
model.feat_stride_s4                              = 4;
model.feat_stride_s8                              = 8;
model.feat_stride_s16                             = 16;

%% stage 1 rpn, inited from pre-trained network
%0302 note that solver_30k40k_final3, and test_final3 are the current best result!!!
% solver_30k40k_final3_nodivanchor, test_final3_nodivanchor ==> original mpfpn model
% solver_30k40k_mpfpn_centerloss, test_mpfpn_centerloss ==> mpfpn with centerloss
%0817 changed: vn7 -- use noradius caffe version, puck -- use radius caffe version
if ispc
model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_leave','mpfpn_centerloss', 'solver_30k40k_mpfpn_centerloss_noradius.prototxt'); 
model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_leave','mpfpn_centerloss', 'test_mpfpn_centerloss_noradius.prototxt');
model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;
else
model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_leave','mpfpn_centerloss', 'solver_30k40k_mpfpn_centerloss.prototxt'); 
model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_leave','mpfpn_centerloss', 'test_mpfpn_centerloss.prototxt');
model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;
end
% rpn test setting
% 0224: same settings for conv3 4 and 5
model.stage1_rpn.nms.per_nms_topN               = -1; %20000
model.stage1_rpn.nms.nms_overlap_thres       	= 0.7;%0111: should also try 0.7 when doing testing
model.stage1_rpn.nms.after_nms_topN         	= 300;%1204:800--100

end
