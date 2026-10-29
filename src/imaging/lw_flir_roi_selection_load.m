function [selection, message] = lw_flir_roi_selection_load(filePath, fallbackSelection)
%LW_FLIR_ROI_SELECTION_LOAD Read the last applied FLIR ROI, or return the fallback.
%   MESSAGE is empty when no saved file exists, and otherwise describes what
%   was loaded or why the saved file was ignored.

selection = fallbackSelection;
message = "";
filePath = string(filePath);
if strlength(filePath) == 0 || ~isfile(filePath)
    return;
end

try
    saved = jsondecode(fileread(filePath));
    selection = lw_flir_roi_selection(saved.Mode, saved);
    message = "Loaded saved FLIR ROI from " + filePath + ".";
catch ME
    selection = fallbackSelection;
    message = "Saved FLIR ROI ignored (" + string(compactErrorMessage(ME)) + "): " + filePath;
end
end
