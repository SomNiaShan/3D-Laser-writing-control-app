function value = lw_flir_read_node_string(nodeMap, baseName, fallback)
%LW_FLIR_READ_NODE_STRING Read a node as text with a fallback.

value = fallback;
node = lw_flir_get_node(nodeMap, baseName);
if ~lw_flir_is_node_readable(node)
    return;
end

try
    value = char(node.ToString());
catch
end
end
