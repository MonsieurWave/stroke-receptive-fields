%% Perfusion Normalisation wrapper script
% This script normalises perfusions maps and CSF-mask to native MNI-CT (better if not skull-stripped) 
% by using the non-betted native CT that the perfusion maps must have been coregistered to.
% It follows a particular directory structure which must
% be adhered to.
%

%% Clear variables and command window
clear all , clc
%% Specify paths
% Experiment folder
data_path = '/Users/julian/temp/standard_prepro_test/standard_test_extracted_nifti_2';
spm_path = '/Users/julian/Documents/MATLAB/spm12';
do_not_recalculate = false; 
with_angio = true;

script_path = mfilename('fullpath');
script_folder = script_path(1 : end - size(mfilename, 2));
addpath(genpath(script_folder));
addpath(genpath(spm_path));

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

use_stripped_template = false; % normalisation works better with skull
template_dir = fullfile(script_folder, '/normalisation');
if(use_stripped_template)
    ct_template = fullfile(template_dir, 'scct_stripped.nii');
else
    ct_template = fullfile(template_dir, 'scct.nii');
end

sequences = {
    'CBF' ,...
    'CBV', ...
    'MTT', ...
    'Tmax'
    };

angio_ct_name = 'betted_Angio_CT_075_Bv40';
angio_vx_ct_name = 'filtered_extracted_betted_Angio_CT_075_Bv40';
angio_mask_ct_name = 'mask_filtered_extracted_betted_Angio_CT_075_Bv40';
angio_ct_suffix = '';
csf_mask_name = 'CSF_mask.nii';

% Base image to co-register to
base_image_dir = data_path;
base_image_name = 'SPC_301mm_Std_';
base_image_prefix = '';
betted_prefix = 'betted_';
if(use_stripped_template)
    base_image_prefix = 'betted_';
end
base_image_ext = '.nii.gz';

addpath(template_dir, data_path)
%% Initialise SPM defaults
%% Loop to load data from folders and run the job
for i = 1: numel ( subjects )
    fprintf('%i/%i (%i%%) \n', i, size(subjects, 1), 100 * i / size(subjects, 1));
    modalities = dir(fullfile(data_path,subjects{i}, 'pCT*'));
    modality = modalities(1).name;

% Verify if normalisation was already done
    wcoreg_count = 0;
    for jj = 1: numel(sequences)
        coreg_sequences = dir(fullfile(base_image_dir, subjects{i}, modality, ...
            strcat('wcoreg_', sequences{jj}, '_', subjects{i}, '*', '.nii*')));
        try
            if exist(fullfile(base_image_dir, subjects{i}, modality, coreg_sequences(1).name))
                wcoreg_count = wcoreg_count + 1;
            end
        catch ME
        end
    end
    norm_csf_mask_names = dir(fullfile(base_image_dir, subjects{i}, modality, ...
            strcat('w', csf_mask_name,'*')));
    norm_angio = dir(fullfile(base_image_dir, subjects{i}, modality, ...
            strcat('w', angio_ct_name, '_' ,subjects{i}, '*', angio_ct_suffix, '.nii*')));
    try
        if exist(fullfile(base_image_dir, subjects{i}, modality, norm_csf_mask_names(1).name))
            wcoreg_count = wcoreg_count + 1;
        end
        if with_angio && exist(fullfile(base_image_dir, subjects{i}, modality, norm_angio(1).name))
            wcoreg_count = wcoreg_count + 1;
        end
    catch ME
    end
        
    if do_not_recalculate && ...
        ((wcoreg_count == size(sequences, 2) + 1 && ~with_angio) || ...
        (wcoreg_count == size(sequences, 2) + 2 && with_angio))
        fprintf('Skipping subject "%s" as normalised files are already present.\n', subjects{i});
        continue;
    end    
    
    base_image_list = dir(fullfile(base_image_dir, subjects{i}, modality, ...
        strcat(base_image_prefix, base_image_name, subjects{i}, '*', '.nii*')));
    base_image = fullfile(base_image_dir, subjects{i}, modality, base_image_list(1).name);
    [filepath,name,ext] = fileparts(base_image);
    if strcmp(ext, '.gz') 
        gunzip(base_image);
        base_image = base_image(1: end - 3);
    end

    % load coregistered data for each sequence without a prompt
    input = {};
    for j = 1: numel(sequences)
        input{end + 1} = fullfile(data_path, subjects{i}, modality, ...
                            strcat('coreg_', sequences{j}, '_' ,subjects{i}, '.nii'));
    end
    
    if with_angio
       angio_file_list = dir(fullfile(data_path, subjects{i}, modality, ...
                            strcat(angio_ct_name, '_' ,subjects{i}, '*', angio_ct_suffix, '.nii*')));
       angio_file = fullfile(data_path, subjects{i}, modality, angio_file_list(1).name);
       angio_vx_file_list = dir(fullfile(data_path, subjects{i}, modality, ...
                            strcat(angio_vx_ct_name, '_' ,subjects{i}, '*', angio_ct_suffix, '.nii*')));
       angio_vx_file = fullfile(data_path, subjects{i}, modality, angio_vx_file_list(1).name);
       angio_mask_file_list = dir(fullfile(data_path, subjects{i}, modality, ...
                            strcat(angio_mask_ct_name, '_' ,subjects{i}, '*', angio_ct_suffix, '.nii*')));
       angio_mask_file = fullfile(data_path, subjects{i}, modality, angio_mask_file_list(1).name);
       
       [filepath,name,ext] = fileparts(angio_file);
        if strcmp(ext, '.gz') 
            gunzip(angio_file);
            angio_file = angio_file(1: end - 3);
        end
        [filepath,name,ext] = fileparts(angio_mask_file);
        if strcmp(ext, '.gz') 
            gunzip(angio_mask_file);
            angio_mask_file = angio_mask_file(1: end - 3);
        end
        [filepath,name,ext] = fileparts(angio_vx_file);
        if strcmp(ext, '.gz') 
            gunzip(angio_vx_file);
            angio_vx_file = angio_vx_file(1: end - 3);
        end
        input{end + 1} = angio_file;
        input{end + 1} = angio_vx_file;
        input{end + 1} = angio_mask_file;
    end 

    % Coregister CSF mask of betted image to template as well
    csf_mask_list = dir(fullfile(base_image_dir, subjects{i}, modality, ...
        strcat(csf_mask_name, '*')));
    csf_mask_image = fullfile(base_image_dir, subjects{i}, modality, csf_mask_list(1).name);
    [filepath,name,ext] = fileparts(csf_mask_image);
    if strcmp(ext, '.gz') 
        gunzip(csf_mask_image);
        csf_mask_image = csf_mask_image(1: end - 3);
    end
    % Work on a copy of the CSF Mask image to be able to
    % eventually repreocess the original later
    csf_mask_to_warp = fullfile(base_image_dir, subjects{i}, modality, ...
        strcat('reor_', csf_mask_name));
    copyfile(csf_mask_image, csf_mask_to_warp);
    input{end + 1} = csf_mask_to_warp;
   
    %% RUN NORMALISATION
    
   % display which subject and sequence is being processed
    fprintf('Processing subject "%s" , "%s" + "%s" (%s files)\n' ,...
        subjects{i}, strjoin(sequences), csf_mask_name, sprintf('%d',size (input ,2)));
    
%     Keep an original copy of the base_image
    base_image_to_warp = fullfile(base_image_dir, subjects{i}, modality, ...
    strcat('reor_', base_image_prefix, base_image_name, subjects{i}, '.nii'));
    copyfile(base_image, base_image_to_warp);
    
%         Script using modern SPM12 normalise function
      normalise_to_CT(base_image_to_warp, input, ct_template);

    
%% (SHOULD NOT BE USED ANYMORE) Script based on Clinical_CT toolbox based on SPM8 normalise 
%           --> not successful
%     lesionMask = '';
%     mask = 1;
%     bb = [-78 -112 -50
%         78 76 85];
%     vox = [1 1 1];
%     DelIntermediate = 0;
%     AutoSetOrigin = 1;
%     useStrippedTemplate = use_stripped_template;
%     perf_clinical_ctnorm(base_image_to_warp, lesionMask, input, vox, bb,DelIntermediate, mask, useStrippedTemplate, AutoSetOrigin);

        
end

