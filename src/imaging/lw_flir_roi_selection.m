function selection = lw_flir_roi_selection(mode, rect)
%LW_FLIR_ROI_SELECTION Build a validated FLIR ROI selection.
%   MODE is "custom", "full", or "top-left-quarter". RECT holds the custom
%   OffsetX, OffsetY, Width, and Height in full-sensor pixels; it is kept for
%   preset modes too so the custom values survive switching back.

modeKey = lower(strtrim(string(mode)));
modeKey = replace(modeKey, "_", "-");
switch modeKey
    case "custom"
        modeKey = "custom";
    case {"full", "native", "full-sensor"}
        modeKey = "full";
    case {"top-left-quarter", "upper-left-quarter", "left-top-quarter"}
        modeKey = "top-left-quarter";
    otherwise
        error('lw:flir:InvalidRoi', 'Unsupported FLIR ROI mode: %s.', char(string(mode)));
end

selection = struct( ...
    'Mode', modeKey, ...
    'OffsetX', roiInteger(rect, 'OffsetX', 0), ...
    'OffsetY', roiInteger(rect, 'OffsetY', 0), ...
    'Width', roiInteger(rect, 'Width', 1), ...
    'Height', roiInteger(rect, 'Height', 1));
end

function value = roiInteger(rect, fieldName, minValue)
if ~isstruct(rect) || ~isfield(rect, fieldName)
    error('lw:flir:InvalidRoi', 'FLIR ROI is missing %s.', fieldName);
end
value = double(rect.(fieldName));
if ~isscalar(value) || ~isfinite(value) || value < minValue || value ~= round(value)
    error('lw:flir:InvalidRoi', 'FLIR ROI %s must be an integer >= %d.', fieldName, minValue);
end
end
