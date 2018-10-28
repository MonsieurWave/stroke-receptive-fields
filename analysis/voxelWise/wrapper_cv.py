import sys, shutil
sys.path.insert(0, '../')

import os, timeit, traceback, torch
import numpy as np
import timeit
from vxl_xgboost.external_mem_xgb import External_Memory_xgb
from vxl_xgboost.ram_xgb import Ram_xgb
from vxl_glm.LogReg_glm import LogReg_glm
import visual
import data_loader
import manual_data
from email_notification import NotificationSystem
from cv_framework import repeated_kfold_cv
from figures.train_test_evaluation import wrapper_plot_train_evaluation
from figures.plot_ROC import plot_roc

notification_system = NotificationSystem()

def launch_cv(model_name, Model_Generator, rf_dim, IN, OUT, CLIN,
                n_repeats, n_folds, main_save_dir, main_output_dir):

    if not os.path.exists(main_output_dir):
        os.makedirs(main_output_dir)
    output_dir = os.path.join(main_output_dir, model_name + '_output')

    if os.path.exists(output_dir):
        # file exists
        print('This model already has saved output ', output_dir)
        validation = input('Type `yes` if you wish to delete your previous model:\t')
        if (validation != 'yes'):
            raise ValueError('Model already has saved data. Choose another model name or delete current model')
        else:
            shutil.rmtree(output_dir)

    print('Evaluating', model_name, 'with rf:', rf_dim)

    save_dir = os.path.join(main_save_dir, model_name + '_data')
    if not os.path.exists(save_dir):
        os.makedirs(save_dir)

    try:
        start = timeit.default_timer()
        save_folds = False

        results, trained_models = repeated_kfold_cv(Model_Generator, save_dir,
            input_data_array = IN, output_data_array = OUT, clinical_input_array = CLIN,
            receptive_field_dimensions = rf_dim, n_repeats = n_repeats, n_folds = n_folds, messaging = notification_system)

        accuracy = np.median(results['test_accuracy'])
        roc_auc = np.median(results['test_roc_auc'])
        f1 = np.median(results['test_f1'])
        params = results['model_params']

        print('Results for', model_name)
        print('Voxel-wise accuracy: ', accuracy)
        print('ROC AUC score: ', roc_auc)
        print('F1 score: ', f1)

        # save the results and the params objects
        os.makedirs(output_dir)
        torch.save(results, os.path.join(output_dir, 'scores_' + model_name + '.npy'))
        torch.save(results['model_params'], os.path.join(output_dir, 'params_' + model_name + '.npy'))
        torch.save(trained_models, os.path.join(output_dir, 'trained_models_' + model_name + '.npy'))
        wrapper_plot_train_evaluation(os.path.join(output_dir, 'scores_' + model_name + '.npy'), save_plot = True)
        plot_roc(results['test_TPR'], results['test_FPR'], output_dir, model_name, save_plot = True)

        elapsed = timeit.default_timer() - start
        print('Evaluation done in: ', elapsed)
        title = model_name + ' finished Cross-Validation'
        body = 'accuracy ' + str(accuracy) + '\n' + 'ROC AUC ' + str(roc_auc) + '\n' + 'F1 ' + str(f1) + '\n' + 'RF ' + str(rf_dim) + '\n' + 'Time elapsed ' + str(elapsed) + '\n' + str(params)
        notification_system.send_message(title, body)

        if not save_folds:
            # Erase saved fold to free up space
            try:
                shutil.rmtree(save_dir)
            except:
                print('No directory to clear.')

    except Exception as e:
        title = model_name + ' errored upon rf_hyperopt'
        tb = traceback.format_exc()
        body = 'RF ' + str(rf_dim) + '\n' + 'Error ' + str(e) + '\n' + str(tb)
        notification_system.send_message(title, body)
        raise