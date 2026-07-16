function batchSetTableData(tableHandle, data)
names = batchColumnNames();
if isempty(data)
    data = cell(0, numel(names));
end
if size(data, 2) ~= numel(names)
    normalizedData = cell(size(data, 1), numel(names));
    defaults = batchDefaultRow(1);
    for rowIndex = 1:size(data, 1)
        normalizedData(rowIndex, :) = defaults;
        normalizedData(rowIndex, 1:min(size(data, 2), numel(names))) = ...
            data(rowIndex, 1:min(size(data, 2), numel(names)));
    end
    data = normalizedData;
end
tableHandle.Data = data;
end
