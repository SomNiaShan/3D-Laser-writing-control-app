function tf = lw_flir_is_node_writable(node)
%LW_FLIR_IS_NODE_WRITABLE True when a GenICam node can be written.

tf = false;
if isempty(node)
    return;
end
try
    tf = logical(node.IsWritable);
catch
end
end
