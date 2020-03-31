function [] = apply_motion_correction(V0_file)
%APPLY_MOTION_CORRECTION Apply motion correction to a 4D file
%   Prerequisite Matlab toolboxes need to be in path: SPM12, DPABI
%   Input:
%       1. V0_file: File struct for the original 4D volume 
    
%% Load the initial 4D data
% V0_file = dir(fullfile(input_dir, 'VPCT*.nii'));
[~, V0_name, V0_ext] = fileparts(fullfile(V0_file.folder, V0_file.name));
V0_header = spm_vol(fullfile(V0_file.folder, V0_file.name));
V0 = spm_read_vols(V0_header);

%%  Split 4D into multiple 3D volume for SPM realignement
split_4D_subfolder = fullfile(V0_file.folder, '/4D_split');
mkdir(split_4D_subfolder);
spm_file_split(fullfile(V0_file.folder, V0_file.name), split_4D_subfolder);

%%  Run SPM realignement
settings = load('motion_correction/settings.mat');
settings.matlabbatch{1}.spm.spatial.realign.estimate.data = textscan(ls(fullfile(split_4D_subfolder, '*.nii')), '%s', 'delimiter', '\n')

spm('defaults', 'FMRI');
spm_jobman('run', settings.matlabbatch);
%% build X
%1. add constant linear & quadratic trends
X=[ones(size(V0,4),1) [1:size(V0,4)]'/size(V0,4) ...
    [1:size(V0,4)].^2'/(size(V0,4)^2)];
%2. add motion params:
mot = dir(fullfile(split_4D_subfolder,'rp*.txt'));
motion_file = fullfile(main_dir, 'motion_params_' + V0_name + '.txt');    
copyfile(fullfile(split_4D_subfolder, mot(1).name), motion_file);

Cov = load(motion_file);
X=[X,Cov(:,1:6)]; % take first 6 variables (not derivative if they are there)

%% Voxel level GLM 
% V0Cov is the cleaned resulting 4D volume (residuals of the GLM)
V0Cov=zeros(size(V0));
V0idx=(1:size(V0,4));
for i=1:size(V0,1)
    for j=1:size(V0,2)
        for k=1:size(V0,3)
            [beta,res,SSE,SSR,T] = y_regress_ss(squeeze(V0(i,j,k,V0idx)),X); %GLM
            V0Cov(i,j,k,V0idx)=res+mean(squeeze(V0(i,j,k,V0idx))); %put the mean signal back
        end
    end
end
V0Cov(isnan(V0Cov)) = 0;

%% Save motion corrected output 
V0Cov_header = V0_header(1);
[V0Cov_header.fname] = deal('outputfile.nii');
rest_Write4DNIfTI(V0Cov, V0Cov_header, 'outputfile.nii')

%% Clean up
rmdir(split_4D_subfolder)

end

