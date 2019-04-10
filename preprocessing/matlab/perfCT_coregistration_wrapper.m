%% Perfusion Co-registration script
% This script co-registers perfusions maps to skull-stripped native CT sequences.
% It follows a particular directory structure which must
% be adhered to.
%

%% Clear variables and command window
clear all , clc
%% Specify paths
% Experiment folder
data_path = '/Users/julian/master/data/extracted_test2_noVOI';

if ~(exist(data_path))
    fprintf('Data directory does not exist. Please enter a valid directory.')
end

% Subject folders

% Select individual subjects
% subjects = {
% 'patient1'
% };

% Or select subjects based on folders in data_path
d = dir(data_path);
isub = [d(:).isdir]; %# returns logical vector
subjects = {d(isub).name}';
subjects(ismember(subjects,{'.','..'})) = [];

sequences = {
    'CBF' ,...
    'CBV', ...
    'MTT', ...
    'Tmax'
    };

% Base image to co-register to
base_image_dir = data_path;
base_image_prefix = 'betted';
base_image_ext = '.nii.gz';

%% Initialise SPM defaults
%% Loop to load data from folders and run the job
for i = 1: numel ( subjects )
    modalities = dir(fullfile(data_path,subjects{i}, 'pCT*'));
    modality = modalities(1).name;

    base_image = fullfile(base_image_dir, subjects{i}, modality, ...
        strcat(base_image_prefix, '_SPC_301mm_Std_', subjects{i}, '.nii'));
    if (~ exist(base_image))
        zipped_base_image = strcat(base_image, '.gz');
        gunzip(zipped_base_image);
    end
        
    % load realigned data for each sequence without a prompt
    for j = 1: numel(sequences)
%         cd(fullfile(data_path, subjects{i}, modality));
%         accepted_files = dir(strcat(realignment_prefix, '*.nii'));
        input = fullfile(data_path, subjects{i}, modality, ...
            strcat(sequences{j}, '_' ,subjects{i}, '.nii'));
        % display which subject and sequence is being processed
        fprintf('Processing subject "%s" , "%s" (%s files )\n' ,...
            subjects{i}, char(sequences{j}), sprintf('%d',size (input ,1)));
        %% SAVE AND RUN JOB
        %
        coregistration = coregister_job(base_image, input, {});
        log_file = fullfile(data_path, subjects{i}, modality, ...
            'logs',strcat(sequences{j}, '_coreg.mat'));
        mkdir(fullfile(data_path, subjects{i}, modality, 'logs'));
        save(log_file, 'coregistration');
        spm('defaults', 'FMRI');
        spm_jobman('run', coregistration);
    end  
        
end

