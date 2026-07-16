function value = lw_flir_set_integer_node(nodeMap, baseName, value, mustExist)
%LW_FLIR_SET_INTEGER_NODE Set a GenICam integer node, honoring min/max/increment.

if nargin < 4
    mustExist = true;
end

node = lw_flir_get_node(nodeMap, baseName);
if isempty(node)
    if mustExist
        error('Node %s is not available.', baseName);
    end
    return;
end
if ~lw_flir_is_node_writable(node)
    if mustExist
        error('Node %s is not writable.', baseName);
    end
    return;
end

value = round(double(value));
try
    minValue = double(node.Min);
    maxValue = double(node.Max);
    value = max(minValue, min(maxValue, value));
    increment = double(node.Increment);
    if increment > 0
        value = minValue + floor((value - minValue) / increment) * increment;
    end
catch
end

node.Value = int64(value);
try
    value = double(node.Value);
catch
end
end
