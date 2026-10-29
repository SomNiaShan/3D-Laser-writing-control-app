function limits = lw_flir_read_roi_limits(nodeMap)
%LW_FLIR_READ_ROI_LIMITS Read the FLIR sensor size and ROI step constraints.

widthNode = lw_flir_get_node(nodeMap, 'Width');
heightNode = lw_flir_get_node(nodeMap, 'Height');
if isempty(widthNode) || isempty(heightNode) || ...
        ~lw_flir_is_node_readable(widthNode) || ~lw_flir_is_node_readable(heightNode)
    error('Camera Width/Height nodes are not readable.');
end

current = lw_flir_read_current_roi(nodeMap, "current");
limits = struct( ...
    'SensorWidth', current.SensorWidth, ...
    'SensorHeight', current.SensorHeight, ...
    'WidthMin', localReadIntegerProperty(widthNode, 'Min', 1), ...
    'HeightMin', localReadIntegerProperty(heightNode, 'Min', 1), ...
    'WidthIncrement', localReadIntegerProperty(widthNode, 'Increment', 1), ...
    'HeightIncrement', localReadIntegerProperty(heightNode, 'Increment', 1), ...
    'OffsetXIncrement', localReadOptionalIncrement(nodeMap, 'OffsetX'), ...
    'OffsetYIncrement', localReadOptionalIncrement(nodeMap, 'OffsetY'), ...
    'IsWritable', lw_flir_is_node_writable(widthNode) && lw_flir_is_node_writable(heightNode));
end

function value = localReadOptionalIncrement(nodeMap, baseName)
value = 1;
node = lw_flir_get_node(nodeMap, baseName);
if isempty(node) || ~lw_flir_is_node_readable(node)
    return;
end
value = localReadIntegerProperty(node, 'Increment', 1);
end

function value = localReadIntegerProperty(node, propertyName, fallback)
try
    switch char(propertyName)
        case 'Min'
            value = double(node.Min);
        case 'Increment'
            value = double(node.Increment);
        otherwise
            value = fallback;
    end
catch
    value = fallback;
end

if isempty(value) || ~isscalar(value) || ~isfinite(value)
    value = fallback;
    return;
end
value = max(1, round(value));
end
