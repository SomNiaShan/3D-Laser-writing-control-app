function root = lw_setup_project()
%LW_SETUP_PROJECT Add the project folders to the MATLAB path.

scriptDir = fileparts(mfilename('fullpath'));
root = fileparts(scriptDir);
addpath(root);
addpath(fullfile(root, 'app'));
addpath(fullfile(root, 'config'));
addpath(genpath(fullfile(root, 'src')));
addpath(genpath(fullfile(root, 'scripts')));
addpath(genpath(fullfile(root, 'slm_control')));
end
