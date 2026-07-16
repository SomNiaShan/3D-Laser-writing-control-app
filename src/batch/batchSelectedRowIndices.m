function selectedRows = batchSelectedRowIndices(tableHandle, currentSelection)
data = batchNormalizedTableData(tableHandle);
if isempty(data)
    selectedRows = [];
    return;
end
selectedRows = currentSelection;
selectedRows = selectedRows(selectedRows >= 1 & selectedRows <= size(data, 1));
if isempty(selectedRows)
    selectedRows = 1;
end
selectedRows = unique(selectedRows, 'stable');
end
