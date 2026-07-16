function formats = batchColumnFormats()
formats = repmat({'numeric'}, 1, numel(batchColumnNames()));
formats{batchColumnIndex('Enabled')} = 'logical';
formats{batchColumnIndex('Name')} = 'char';
formats{batchColumnIndex('AxiconMode')} = batchAxiconModeItems();
formats{batchColumnIndex('Notes')} = 'char';
end
