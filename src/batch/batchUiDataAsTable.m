function tableValue = batchUiDataAsTable(tableHandle)
data = batchNormalizedTableData(tableHandle);
tableValue = cell2table(data, 'VariableNames', batchColumnNames());
end
