function fig = laser_writing_app_refactored(serviceOverrides)
%LASER_WRITING_APP_REFACTORED Start the isolated refactored application.

if nargin < 1
    serviceOverrides = struct();
end

refactorRoot = fileparts(mfilename('fullpath'));
projectRoot = refactorRoot;
setupDir = fullfile(projectRoot, 'scripts');
setupFile = fullfile(setupDir, 'lw_setup_project.m');
if isfile(setupFile)
    addpath(setupDir);
    lw_setup_project();
else
    error('Standalone app setup file is missing: %s', setupFile);
end

controller = lw.app.AppController(string(projectRoot), serviceOverrides);
fig = controller.Figure;
end
