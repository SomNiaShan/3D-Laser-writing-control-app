function job = batchSelectedJobFromTable(tableHandle, currentSelection)
data = batchNormalizedTableData(tableHandle);
selectedRow = batchSelectedRowIndex(tableHandle, currentSelection);
if isempty(selectedRow)
    error('Select a batch row first.');
end
job = batchJobFromDataRow(data(selectedRow, :), selectedRow);
job.batchIndex = selectedRow;
end
