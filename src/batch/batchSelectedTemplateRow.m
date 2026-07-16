function row = batchSelectedTemplateRow(tableHandle, currentSelection)
data = batchNormalizedTableData(tableHandle);
selectedRow = batchSelectedRowIndex(tableHandle, currentSelection);
if isempty(selectedRow)
    row = batchDefaultRow(1);
else
    row = data(selectedRow, :);
end
end
