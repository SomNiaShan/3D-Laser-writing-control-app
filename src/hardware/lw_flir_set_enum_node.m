function didSet = lw_flir_set_enum_node(nodeMap, baseName, value, mustExist)
%LW_FLIR_SET_ENUM_NODE Set a GenICam enum node by symbolic value.

if nargin < 4
    mustExist = true;
end
didSet = false;

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

node.FromString(value);
didSet = true;
end
