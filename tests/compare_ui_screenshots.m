function result = compare_ui_screenshots(outputFolder)
%COMPARE_UI_SCREENSHOTS Compare the standalone GUI with its locked image.

refactorRoot = fileparts(fileparts(mfilename('fullpath')));
baselinePath = fullfile(refactorRoot, 'tests', 'baseline', ...
    'laser_writing_app_refactored_baseline.png');
if ~isfile(baselinePath)
    error('lw:app:MissingScreenshotBaseline', ...
        'Screenshot baseline is missing: %s', baselinePath);
end

if nargin < 1 || strlength(string(outputFolder)) == 0
    outputFolder = fullfile(tempdir, 'laser_writing_ui_comparison');
end
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

addpath(fullfile(refactorRoot, 'scripts'));
lw_setup_project();
addpath(fullfile(refactorRoot, 'tests', 'helpers'));

currentPath = fullfile(outputFolder, 'refactored_current.png');
currentFigure = laser_writing_app_refactored();
figureCleanup = onCleanup(@() closeIfValid(currentFigure));
drawnow;
[~, currentHash] = lw_test_ui_signature(currentFigure);
lw_normalize_dynamic_ui_for_screenshot(currentFigure);
exportapp(currentFigure, currentPath);

baselineImage = imread(baselinePath);
currentImage = imread(currentPath);
if ~isequal(size(baselineImage), size(currentImage))
    error('UI screenshots have different sizes.');
end

delta = abs(double(baselineImage) - double(currentImage));
changedPixels = any(delta > 2, 3);
expectedHash = "d3e089b229289266edaadd6820f3094987982a03be3f877cdbb74daa53f0aa37";
result = struct( ...
    'baselinePath', string(baselinePath), ...
    'currentPath', string(currentPath), ...
    'expectedHash', expectedHash, ...
    'currentHash', currentHash, ...
    'changedPixelFraction', nnz(changedPixels) / numel(changedPixels), ...
    'meanAbsoluteError', mean(delta, 'all'), ...
    'maximumAbsoluteError', max(delta, [], 'all'));

if currentHash ~= expectedHash
    error('Refactored normalized GUI signature differs from the locked baseline.');
end
if result.changedPixelFraction > 0.005 || result.meanAbsoluteError > 0.1
    error('UI screenshot difference exceeds tolerance (changed %.4f%%, MAE %.4f).', ...
        100 * result.changedPixelFraction, result.meanAbsoluteError);
end
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
