function roi = lw_flir_read_current_roi(nodeMap, regionName)
%LW_FLIR_READ_CURRENT_ROI Read the active FLIR ROI without changing it.

if nargin < 2 || isempty(regionName)
    regionName = "current";
end

widthNode = lw_flir_get_node(nodeMap, 'Width');
heightNode = lw_flir_get_node(nodeMap, 'Height');
if isempty(widthNode) || isempty(heightNode) || ...
        ~lw_flir_is_node_readable(widthNode) || ~lw_flir_is_node_readable(heightNode)
    error('Camera Width/Height nodes are not readable.');
end

width = localReadIntegerValue(widthNode, NaN);
height = localReadIntegerValue(heightNode, NaN);
if ~isfinite(width) || ~isfinite(height)
    error('Camera Width/Height values are not readable.');
end

offsetX = localReadOptionalIntegerNode(nodeMap, 'OffsetX', 0);
offsetY = localReadOptionalIntegerNode(nodeMap, 'OffsetY', 0);
sensorWidth = localReadSensorExtent(nodeMap, 'WidthMax', widthNode, width + offsetX);
sensorHeight = localReadSensorExtent(nodeMap, 'HeightMax', heightNode, height + offsetY);

roi = struct( ...
    'Name', string(regionName), ...
    'OffsetX', offsetX, ...
    'OffsetY', offsetY, ...
    'Width', width, ...
    'Height', height, ...
    'SensorWidth', sensorWidth, ...
    'SensorHeight', sensorHeight);
end

function value = localReadSensorExtent(nodeMap, maxNodeName, sizeNode, usedExtent)
% WidthMax/HeightMax report the full range; Width.Max shrinks as OffsetX grows.
value = localReadOptionalIntegerNode(nodeMap, maxNodeName, NaN);
if isfinite(value) && value >= usedExtent
    return;
end
value = localReadIntegerLimit(sizeNode, 'Max', usedExtent);
end

function value = localReadOptionalIntegerNode(nodeMap, baseName, fallback)
value = fallback;
node = lw_flir_get_node(nodeMap, baseName);
if isempty(node) || ~lw_flir_is_node_readable(node)
    return;
end
value = localReadIntegerValue(node, fallback);
end

function value = localReadIntegerValue(node, fallback)
try
    value = double(node.Value);
catch
    try
        value = str2double(char(node.ToString()));
    catch
        value = fallback;
    end
end

if isempty(value) || ~isscalar(value) || ~isfinite(value)
    value = fallback;
    return;
end
value = round(value);
end

function value = localReadIntegerLimit(node, limitName, fallback)
try
    switch char(limitName)
        case 'Max'
            value = double(node.Max);
        case 'Min'
            value = double(node.Min);
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
value = max(round(value), fallback);
end
