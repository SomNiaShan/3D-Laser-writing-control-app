function data = batchDefaultTableData(rowCount)
names = batchColumnNames();
data = cell(rowCount, numel(names));
for rowIndex = 1:rowCount
    data(rowIndex, :) = batchDefaultRow(rowIndex);
end
end
