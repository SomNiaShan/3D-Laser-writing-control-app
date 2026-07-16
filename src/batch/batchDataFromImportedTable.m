function data = batchDataFromImportedTable(importedTable)
names = batchColumnNames();
data = cell(height(importedTable), numel(names));
importedNames = string(importedTable.Properties.VariableNames);
for rowIndex = 1:height(importedTable)
    data(rowIndex, :) = batchDefaultRow(rowIndex);
    for columnIndex = 1:numel(names)
        matchIndex = find(importedNames == string(names{columnIndex}), 1, 'first');
        if isempty(matchIndex)
            continue;
        end
        data{rowIndex, columnIndex} = importedTableValue(importedTable, rowIndex, matchIndex);
    end
end
end

function value = importedTableValue(importedTable, rowIndex, columnIndex)
columnData = importedTable{rowIndex, columnIndex};
if iscell(columnData)
    value = columnData{1};
else
    value = columnData;
end
if isstring(value) && isscalar(value)
    value = char(value);
end
end
