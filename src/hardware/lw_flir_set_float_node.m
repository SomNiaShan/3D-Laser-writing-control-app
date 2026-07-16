function value = lw_flir_set_float_node(nodeMap, baseName, value)
%LW_FLIR_SET_FLOAT_NODE Set a GenICam float node, clamped to camera limits.

node = lw_flir_get_node(nodeMap, baseName);
if isempty(node) || ~lw_flir_is_node_writable(node)
    error('Node %s is not writable.', baseName);
end

value = double(value);
try
    value = max(double(node.Min), min(double(node.Max), value));
catch
end
node.Value = value;
try
    value = double(node.Value);
catch
end
end
