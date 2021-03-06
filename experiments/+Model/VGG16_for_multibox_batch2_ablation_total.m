function model = VGG16_for_multibox_batch2_ablation_total(exp_name, model)


model.mean_image                                = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'mean_image');
model.pre_trained_net_file                      = fullfile(pwd, 'models', exp_name, 'pre_trained_models', 'vgg_16layers', 'vgg16.caffemodel');
% Stride in input image pixels at the last conv layer
%model.feat_stride                               = 16;
model.feat_stride_s4                              = 4;
model.feat_stride_s8                              = 8;
model.feat_stride_s16                             = 16;

%% stage 1 rpn, inited from pre-trained network
%0308: Currently nodivanchor and divanchor share the same prototxt
model.stage1_rpn.solver_def_file                = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_16layers_ablation', 'final_models', 'solver_30k40k_final3_nodivanchor_flip.prototxt'); 
model.stage1_rpn.test_net_def_file              = fullfile(pwd, 'models', exp_name, 'rpn_prototxts', 'vgg_16layers_ablation', 'final_models', 'test_final3_nodivanchor_flip.prototxt');
model.stage1_rpn.init_net_file                  = model.pre_trained_net_file;

% rpn test setting
% 0224: same settings for conv3 4 and 5
model.stage1_rpn.nms.per_nms_topN               = -1; %20000
model.stage1_rpn.nms.nms_overlap_thres       	= 0.7;%0111: should also try 0.7 when doing testing
model.stage1_rpn.nms.after_nms_topN         	= 300;%1204:800--100

end