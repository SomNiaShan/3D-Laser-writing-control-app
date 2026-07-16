function widths = batchColumnWidths()
widths = repmat({112}, 1, numel(batchColumnNames()));
widths{batchColumnIndex('Enabled')} = 70;
widths{batchColumnIndex('Name')} = 130;
widths{batchColumnIndex('AxiconMode')} = 140;
widths{batchColumnIndex('Notes')} = 160;
end
