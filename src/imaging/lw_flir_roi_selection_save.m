function lw_flir_roi_selection_save(filePath, selection, cameraLabel)
%LW_FLIR_ROI_SELECTION_SAVE Persist the applied FLIR ROI for the next app start.

if nargin < 3
    cameraLabel = "";
end
filePath = char(string(filePath));
if isempty(filePath)
    error('FLIR ROI settings file is not configured.');
end

folderPath = fileparts(filePath);
if ~isempty(folderPath) && ~isfolder(folderPath)
    mkdir(folderPath);
end

payload = struct( ...
    'Mode', char(selection.Mode), ...
    'OffsetX', selection.OffsetX, ...
    'OffsetY', selection.OffsetY, ...
    'Width', selection.Width, ...
    'Height', selection.Height, ...
    'Camera', char(string(cameraLabel)), ...
    'SavedAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

fileId = fopen(filePath, 'w');
if fileId < 0
    error('Could not write FLIR ROI settings file: %s', filePath);
end
cleanupObj = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(payload, 'PrettyPrint', true));
clear cleanupObj
end
