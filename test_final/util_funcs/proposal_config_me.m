function conf = proposal_config_me(varargin)
% conf = proposal_config_caltech(varargin)
% --------------------------------------------------------
% RPN_BF
% Copyright (c) 2016, Liliang Zhang
% Licensed under The MIT License [see LICENSE for details]
% --------------------------------------------------------

    ip = inputParser;
    
    %% training
    ip.addParamValue('use_gpu',         gpuDeviceCount > 0, ...            %
                                                        @islogical);
                                    
%     % whether drop the anchors that has edges outside of the image boundary
    ip.addParamValue('drop_boxes_runoff_image', ...
                                        true,           @islogical);
                                    
%    ip.addParamValue('drop_fg_boxes_runoff_image', ...
%                                         true,           @islogical);
    
    % 0123 added for min and max test image size
    ip.addParamValue('min_test_length', 64,           @isscalar);
    ip.addParamValue('max_test_length', 5000,           @isscalar);%3008
    % Image scales -- the short edge of input image                                                                                                
    ip.addParamValue('scales',          800,            @ismatrix); %512
    % Max pixel size of a scaled input image
    ip.addParamValue('max_size',        5000,           @isscalar); %800
    % Images per batch, only supports ims_per_batch = 1 currently
    ip.addParamValue('ims_per_batch',   2,              @isscalar);%0312:6->3
    % Minibatch size  0228: 360 (batch6) -> 240 (batch6)
    %0308 changed to divide 3 paths
    %ip.addParamValue('batch_size',      240,            @isscalar); %original 120,0122: 256(for 1 image)  --> 240 (for 3 images) 
    ip.addParamValue('batch_size_s4',    32,            @isscalar); %0312: 96 (for 6 images) ->48 (for 3 images)
    ip.addParamValue('batch_size_s8',    64,            @isscalar); %0312:144 (for 6 images) ->96 (for 3 images)
    ip.addParamValue('batch_size_s16',   16,            @isscalar); %0312: 48 (for 6 images) -> 24 (for 3 images)
    % Fraction of minibatch that is foreground labeled (class > 0)
    ip.addParamValue('fg_fraction',     0.25,           @isscalar); %1/6
    % weight of background samples, when weight of foreground samples is
    % 1.0
    ip.addParamValue('bg_weight',       0.5,            @isscalar);%0224: 1-->0.5
    % Overlap threshold for a ROI to be considered foreground (if >= fg_thresh)
    ip.addParamValue('fg_thresh',       0.5,            @isscalar);
    % Overlap threshold for a ROI to be considered background (class = 0 if
    % overlap in [bg_thresh_lo, bg_thresh_hi))
    ip.addParamValue('bg_thresh_hi',    0.3,            @isscalar); %0.5
    ip.addParamValue('bg_thresh_lo',    0,              @isscalar);
    % mean image, in RGB order
    ip.addParamValue('image_means',     256,            @ismatrix);
    % Use horizontally-flipped images during training?
    ip.addParamValue('use_flipped',     false,          @islogical);
    % Stride in input image pixels at ROI pooling level (network specific)
    % 16 is true for {Alex,Caffe}Net, VGG_CNN_M_1024, and VGG16
    %ip.addParamValue('feat_stride',     16,             @isscalar);
    ip.addParamValue('feat_stride_s4',     4,             @isscalar);
    ip.addParamValue('feat_stride_s8',     8,             @isscalar);
    ip.addParamValue('feat_stride_s16',    16,             @isscalar);
    % train proposal target only to labled ground-truths or also include
    % other proposal results (selective search, etc.)
    ip.addParamValue('target_only_gt',  true,           @islogical);

    % random seed                    
    ip.addParamValue('rng_seed',        6,              @isscalar);

    
    %% testing
    ip.addParamValue('test_scales',     800,            @isscalar); %720
    % 0124 added
    ip.addParamValue('test_scale_range',[0.5 1 2],      @isvector); %720
    ip.addParamValue('test_max_size',   5000,            @isscalar); % 800
    ip.addParamValue('test_nms',        0.5,            @isscalar);
    ip.addParamValue('test_binary',     false,          @islogical);
    ip.addParamValue('test_min_box_size',8,            @isscalar); %16
    ip.addParamValue('test_min_box_height',8,            @isscalar); %50
    ip.addParamValue('test_drop_boxes_runoff_image', ...
                                        false,          @islogical);
    
    ip.parse(varargin{:});
    conf = ip.Results;
    
    %assert(conf.ims_per_batch == 1, 'currently rpn only supports ims_per_batch == 1');
    
    assert(conf.scales == conf.test_scales);
    assert(conf.max_size == conf.test_max_size);
    
    % if image_means is a file, load it
    if ischar(conf.image_means)
        s = load(conf.image_means);
        s_fieldnames = fieldnames(s);
        assert(length(s_fieldnames) == 1);
        conf.image_means = s.(s_fieldnames{1});
    end
end
