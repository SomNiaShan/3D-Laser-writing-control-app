function data = batchNormalizedTableData(tableHandle)
names = batchColumnNames();
data = tableHandle.Data;
if istable(data)
    data = table2cell(data);
end
if isempty(data)
    data = cell(0, numel(names));
    return;
end
if ~iscell(data)
    data = num2cell(data);
end
if size(data, 2) < numel(names)
    defaults = batchDefaultRow(1);
    paddedData = cell(size(data, 1), numel(names));
    for rowIndex = 1:size(data, 1)
        paddedData(rowIndex, :) = defaults;
        paddedData(rowIndex, 1:size(data, 2)) = data(rowIndex, :);
    end
    data = paddedData;
elseif size(data, 2) > numel(names)
    data = data(:, 1:numel(names));
end
end
