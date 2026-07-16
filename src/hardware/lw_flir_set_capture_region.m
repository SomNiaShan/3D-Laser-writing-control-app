function [flir, width, height, regionInfo] = lw_flir_set_capture_region(flir, regionName)
%LW_FLIR_SET_CAPTURE_REGION Configure the FLIR sensor area used for capture.

if nargin < 2 || isempty(regionName)
    regionName = "full";
end

regionKey = lower(strtrim(string(regionName)));
regionKey = replace(regionKey, "_", "-");

switch regionKey
    case {"full", "native", "full-sensor"}
        [flir, width, height] = lw_flir_set_native_resolution(flir);
        regionInfo = flir.currentRoi;
    case {"top-left-quarter", "upper-left-quarter", "left-top-quarter"}
        [flir, width, height, regionInfo] = lw_flir_set_top_left_quarter_resolution(flir);
    otherwise
        error('Unsupported FLIR capture region: %s.', char(regionName));
end
end
