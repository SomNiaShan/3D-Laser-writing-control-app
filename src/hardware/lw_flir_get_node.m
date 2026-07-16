function node = lw_flir_get_node(nodeMap, baseName)
%LW_FLIR_GET_NODE Find a GenICam node by plain, Std::, or Cust:: name.

node = [];
if isempty(nodeMap)
    return;
end

candidates = {baseName, ['Std::' baseName], ['Cust::' baseName]};
for k = 1:numel(candidates)
    try
        if nodeMap.ContainsKey(candidates{k})
            node = nodeMap.Item(candidates{k});
            return;
        end
    catch
    end
end

try
    suffix = ['::' baseName];
    iterator = nodeMap.GetEnumerator();
    while iterator.MoveNext()
        key = char(iterator.Current.Key);
        if strcmp(key, baseName) || endsWith(key, suffix)
            node = iterator.Current.Value;
            return;
        end
    end
catch
    node = [];
end
end
