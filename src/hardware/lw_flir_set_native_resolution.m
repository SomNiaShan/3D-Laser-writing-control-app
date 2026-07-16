function [flir, width, height] = lw_flir_set_native_resolution(flir)
%LW_FLIR_SET_NATIVE_RESOLUTION Use full sensor width and height.

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

roi = lw_flir_read_current_roi(flir.nodeMap, "full");
if lw_flir_is_node_writable(widthNode) && lw_flir_is_node_writable(heightNode)
    lw_flir_set_integer_node(flir.nodeMap, 'OffsetX', 0, false);
    lw_flir_set_integer_node(flir.nodeMap, 'OffsetY', 0, false);
    lw_flir_set_integer_node(flir.nodeMap, 'Width', double(widthNode.Max), true);
    lw_flir_set_integer_node(flir.nodeMap, 'Height', double(heightNode.Max), true);
    roi = lw_flir_read_current_roi(flir.nodeMap, "full");
elseif roi.OffsetX ~= 0 || roi.OffsetY ~= 0 || ...
        roi.Width ~= roi.SensorWidth || roi.Height ~= roi.SensorHeight
    roi.Name = "current-read-only";
end

width = roi.Width;
height = roi.Height;
flir.currentRoi = roi;
end
