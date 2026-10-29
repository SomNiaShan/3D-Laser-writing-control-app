function [flir, width, height, regionInfo] = lw_flir_set_capture_region(flir, region)
%LW_FLIR_SET_CAPTURE_REGION Configure the FLIR sensor area used for capture.
%   REGION is a preset name ("full" or "top-left-quarter") or a struct with
%   OffsetX, OffsetY, Width, and Height in full-sensor pixels.

if nargin < 2 || isempty(region)
    region = "full";
end

if isstruct(region)
    [flir, width, height, regionInfo] = lw_flir_set_custom_roi(flir, region);
    return;
end

regionKey = lower(strtrim(string(region)));
regionKey = replace(regionKey, "_", "-");

switch regionKey
    case {"full", "native", "full-sensor"}
        [flir, width, height] = lw_flir_set_native_resolution(flir);
        regionInfo = flir.currentRoi;
    case {"top-left-quarter", "upper-left-quarter", "left-top-quarter"}
        [flir, width, height, regionInfo] = lw_flir_set_top_left_quarter_resolution(flir);
    otherwise
        error('Unsupported FLIR capture region: %s.', char(region));
end
end
