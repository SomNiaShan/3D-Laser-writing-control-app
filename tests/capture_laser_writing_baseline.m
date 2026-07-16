function baseline = capture_laser_writing_baseline(outputFolder)
%CAPTURE_LASER_WRITING_BASELINE Capture the standalone refactored UI baseline.

refactorRoot = fileparts(fileparts(mfilename('fullpath')));

if nargin < 1 || strlength(string(outputFolder)) == 0
    outputFolder = fullfile(refactorRoot, 'tests', 'baseline');
end

projectRoot = refactorRoot;
addpath(fullfile(projectRoot, 'scripts'));
lw_setup_project();
helperPath = fullfile(refactorRoot, 'tests', 'helpers');
addpath(helperPath);
helperCleanup = onCleanup(@() rmpath(helperPath));

fig = laser_writing_app_refactored();
figureCleanup = onCleanup(@() closeIfValid(fig));
drawnow;
[signature, hash] = lw_test_ui_signature(fig);
baseline = struct( ...
    'componentCount', numel(findall(fig)), ...
    'signature', signature, ...
    'hash', hash, ...
    'figureName', string(fig.Name), ...
    'figurePosition', fig.Position);
lw_normalize_dynamic_ui_for_screenshot(fig);

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
save(fullfile(outputFolder, 'laser_writing_app_refactored_baseline.mat'), 'baseline');
exportapp(fig, fullfile(outputFolder, 'laser_writing_app_refactored_baseline.png'));
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
