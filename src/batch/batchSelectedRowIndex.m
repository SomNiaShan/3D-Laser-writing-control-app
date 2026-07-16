function selectedRow = batchSelectedRowIndex(tableHandle, currentSelection)
selectedRows = batchSelectedRowIndices(tableHandle, currentSelection);
if isempty(selectedRows)
    selectedRow = [];
else
    selectedRow = selectedRows(1);
end
end
