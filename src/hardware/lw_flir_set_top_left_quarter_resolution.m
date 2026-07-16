function [flir, width, height, roi] = lw_flir_set_top_left_quarter_resolution(flir)
%LW_FLIR_SET_TOP_LEFT_QUARTER_RESOLUTION Use the top-left quarter sensor ROI.

if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end
if isfield(flir, 'isAcquiring') && logical(flir.isAcquiring)
    error('Stop FLIR acquisition before changing resolution.');
end

widthNode = lw_flir_get_node(flir.nodeMap, 'Width');
heightNode = lw_flir_get_node(flir.nodeMap, 'Height');
if isempty(widthNode) || isempty(heightNode)
    error('Camera Width/Height nodes are not available.');
end

if ~lw_flir_is_node_writable(widthNode) || ~lw_flir_is_node_writable(heightNode)
    roi = lw_flir_read_current_roi(flir.nodeMap, "current-read-only");
    width = roi.Width;
    height = roi.Height;
    flir.currentRoi = roi;
    return;
end

lw_flir_set_integer_node(flir.nodeMap, 'OffsetX', 0, false);
lw_flir_set_integer_node(flir.nodeMap, 'OffsetY', 0, false);

sensorWidth = double(widthNode.Max);
sensorHeight = double(heightNode.Max);
lw_flir_set_integer_node(flir.nodeMap, 'Width', floor(sensorWidth / 2), true);
lw_flir_set_integer_node(flir.nodeMap, 'Height', floor(sensorHeight / 2), true);

% Keep the ROI anchored to the upper-left corner after Width/Height changes.
lw_flir_set_integer_node(flir.nodeMap, 'OffsetX', 0, false);
lw_flir_set_integer_node(flir.nodeMap, 'OffsetY', 0, false);

roi = lw_flir_read_current_roi(flir.nodeMap, "top-left-quarter");
roi.SensorWidth = sensorWidth;
roi.SensorHeight = sensorHeight;
width = roi.Width;
height = roi.Height;
flir.currentRoi = roi;
end
