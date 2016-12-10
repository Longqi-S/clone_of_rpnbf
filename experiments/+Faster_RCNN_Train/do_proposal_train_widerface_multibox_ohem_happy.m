function model_stage = do_proposal_train_widerface_multibox_ohem_happy(conf, dataset, model_stage, do_val)
    if ~do_val
        dataset.imdb_test = struct();
        dataset.roidb_test = struct();
    end
    % no plot -- proposal_train_widerface
    % plot train and val curve -- proposal_train_widerface_plot
    model_stage.output_model_file = proposal_train_widerface_multibox_ohem_happy(conf, dataset.imdb_train, dataset.roidb_train, ...
                                    'do_val',           do_val, ...
                                    'imdb_val',         dataset.imdb_test, ...
                                    'roidb_val',        dataset.roidb_test, ...
                                    'solver_def_file',  model_stage.solver_def_file, ...
                                    'net_file',         model_stage.init_net_file, ...
                                    'cache_name',       model_stage.cache_name, ...
                                    'exp_name',         conf.exp_name);
end
