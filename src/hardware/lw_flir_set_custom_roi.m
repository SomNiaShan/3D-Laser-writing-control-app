function [flir, width, height, roi] = lw_flir_set_custom_roi(flir, request)
%LW_FLIR_SET_CUSTOM_ROI Apply a user-defined sensor ROI in full-sensor pixels.
%   REQUEST holds OffsetX, OffsetY, Width, and Height. Values are snapped to
%   the camera increments and clamped to the sensor before they are written.

if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end
if isfield(flir, 'isAcquiring') && logical(flir.isAcquiring)
    error('Stop FLIR acquisition before changing resolution.');
end

limits = lw_flir_read_roi_limits(flir.nodeMap);
if ~limits.IsWritable
    roi = lw_flir_read_current_roi(flir.nodeMap, "current-read-only");
    width = roi.Width;
    height = roi.Height;
    flir.currentRoi = roi;
    return;
end

target = lw_flir_normalize_roi(request, limits);

% Width.Max shrinks as OffsetX grows, so clear the offsets before resizing.
lw_flir_set_integer_node(flir.nodeMap, 'OffsetX', 0, false);
lw_flir_set_integer_node(flir.nodeMap, 'OffsetY', 0, false);
lw_flir_set_integer_node(flir.nodeMap, 'Width', target.Width, true);
lw_flir_set_integer_node(flir.nodeMap, 'Height', target.Height, true);
lw_flir_set_integer_node(flir.nodeMap, 'OffsetX', target.OffsetX, target.OffsetX > 0);
lw_flir_set_integer_node(flir.nodeMap, 'OffsetY', target.OffsetY, target.OffsetY > 0);

roi = lw_flir_read_current_roi(flir.nodeMap, "custom");
width = roi.Width;
height = roi.Height;
flir.currentRoi = roi;
end
