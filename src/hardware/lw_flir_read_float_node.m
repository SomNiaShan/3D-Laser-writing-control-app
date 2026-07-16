function value = lw_flir_read_float_node(nodeMap, baseName, fallback)
%LW_FLIR_READ_FLOAT_NODE Read a GenICam float node with a fallback.

if nargin < 3
    fallback = NaN;
end

value = fallback;
node = lw_flir_get_node(nodeMap, baseName);
if ~lw_flir_is_node_readable(node)
    return;
end

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
end
end
