function model_stage = do_fast_rcnn_train_widerface_ablation_mpfvn_ohem(conf, dataset, model_stage, do_val)
    if ~do_val
        dataset.imdb_test = struct();
        dataset.roidb_test = struct();
    end

    model_stage.output_model_file = fast_rcnn_train_widerface_ablation_mpfvn_ohem(conf, dataset.imdb_train, dataset.roidb_train, ...
                                    'do_val',           do_val, ...
                                    'imdb_val',         dataset.imdb_test, ...
                                    'roidb_val',        dataset.roidb_test, ...
                                    'solver_def_file',  model_stage.solver_def_file, ...
                                    'net_file',         model_stage.init_net_file, ...
                                    'cache_name',       model_stage.cache_name, ...
                                    'exp_name',         conf.exp_name);
end