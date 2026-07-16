function tf = lw_flir_is_node_readable(node)
%LW_FLIR_IS_NODE_READABLE True when a GenICam node can be read.

tf = false;
if isempty(node)
    return;
end
try
    tf = logical(node.IsReadable);
catch
end
end
