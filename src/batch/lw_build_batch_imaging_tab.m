function ui = lw_build_batch_imaging_tab(tab, actionFcn, stopFcn)
ui = struct();

grid = uigridlayout(tab, [1, 2], ...
    'ColumnWidth', {'1.45x', '0.95x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'ColumnSpacing', 10);

tablePanel = uipanel(grid, 'Title', 'SLM Parameter Table');
tablePanel.Layout.Row = 1;
tablePanel.Layout.Column = 1;
tableGrid = uigridlayout(tablePanel, [3, 1], ...
    'RowHeight', {'fit', 'fit', '1x'}, ...
    'Padding', [10, 10, 10, 10], ...
    'RowSpacing', 8);

tableToolbar = uigridlayout(tableGrid, [1, 8], ...
    'ColumnWidth', repmat({'1x'}, 1, 8), ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 6);
tableToolbar.Layout.Row = 1;
ui.BatchAddRowButton = uibutton(tableToolbar, 'Text', 'Add Row', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('addRow'));
ui.BatchAddRowButton.Layout.Column = 1;
ui.BatchDuplicateRowButton = uibutton(tableToolbar, 'Text', 'Duplicate', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('duplicateRow'));
ui.BatchDuplicateRowButton.Layout.Column = 2;
ui.BatchDeleteRowButton = uibutton(tableToolbar, 'Text', 'Delete', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('deleteRow'));
ui.BatchDeleteRowButton.Layout.Column = 3;
ui.BatchMoveUpButton = uibutton(tableToolbar, 'Text', 'Move Up', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('moveRow', -1));
ui.BatchMoveUpButton.Layout.Column = 4;
ui.BatchMoveDownButton = uibutton(tableToolbar, 'Text', 'Move Down', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('moveRow', +1));
ui.BatchMoveDownButton.Layout.Column = 5;
ui.BatchImportButton = uibutton(tableToolbar, 'Text', 'Import CSV', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('importCsv'));
ui.BatchImportButton.Layout.Column = 6;
ui.BatchExportButton = uibutton(tableToolbar, 'Text', 'Export CSV', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('exportCsv'));
ui.BatchExportButton.Layout.Column = 7;
ui.BatchValidateButton = uibutton(tableToolbar, 'Text', 'Validate', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('validateTable'));
ui.BatchValidateButton.Layout.Column = 8;

ui.BatchTableSummaryLabel = uilabel(tableGrid, 'Text', 'No rows loaded.');
ui.BatchTableSummaryLabel.Layout.Row = 2;

ui.BatchSlmTable = uitable(tableGrid, ...
    'ColumnName', batchColumnNames(), ...
    'ColumnEditable', true(1, numel(batchColumnNames())), ...
    'ColumnFormat', batchColumnFormats(), ...
    'ColumnWidth', batchColumnWidths(), ...
    'CellSelectionCallback', @(~, event) actionFcn('tableSelection', event), ...
    'CellEditCallback', @(~, ~) actionFcn('tableEdited'));
ui.BatchSlmTable.Layout.Row = 3;

sidePanel = uipanel(grid, 'Title', 'Batch Controls');
sidePanel.Layout.Row = 1;
sidePanel.Layout.Column = 2;
sideGrid = uigridlayout(sidePanel, [4, 1], ...
    'RowHeight', {'fit', 'fit', 'fit', '1x'}, ...
    'Padding', [10, 10, 10, 10], ...
    'RowSpacing', 10);
enableScrollingIfSupported(sideGrid);

setupPanel = uipanel(sideGrid, 'Title', 'Output and SLM');
setupPanel.Layout.Row = 1;
setupGrid = uigridlayout(setupPanel, [5, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 5), ...
    'Padding', [10, 8, 10, 8], ...
    'RowSpacing', 7);
rightLabel(setupGrid, 'Batch Name', 1, 1);
ui.BatchNameField = uieditfield(setupGrid, 'text');
ui.BatchNameField.Layout.Row = 1;
ui.BatchNameField.Layout.Column = 2;
rightLabel(setupGrid, 'SLM', 2, 1);
ui.BatchSlmStatusLabel = uilabel(setupGrid, 'Text', 'Disconnected');
ui.BatchSlmStatusLabel.Layout.Row = 2;
ui.BatchSlmStatusLabel.Layout.Column = 2;
ui.BatchConnectSlmButton = uibutton(setupGrid, 'Text', 'Connect SLM', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('connectSlm'));
ui.BatchConnectSlmButton.Layout.Row = 3;
ui.BatchConnectSlmButton.Layout.Column = 1;
ui.BatchDisconnectSlmButton = uibutton(setupGrid, 'Text', 'Disconnect SLM', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('disconnectSlm'));
ui.BatchDisconnectSlmButton.Layout.Row = 3;
ui.BatchDisconnectSlmButton.Layout.Column = 2;
ui.BatchPreviewSelectedButton = uibutton(setupGrid, 'Text', 'Preview Selected', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('previewSelected'));
ui.BatchPreviewSelectedButton.Layout.Row = 4;
ui.BatchPreviewSelectedButton.Layout.Column = 1;
ui.BatchShowSelectedButton = uibutton(setupGrid, 'Text', 'Show Selected', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('showSelected'));
ui.BatchShowSelectedButton.Layout.Row = 4;
ui.BatchShowSelectedButton.Layout.Column = 2;
ui.BatchCommonSettingsLabel = uilabel(setupGrid, ...
    'Text', 'Z stack settings come from the 3D Imaging tab.');
ui.BatchCommonSettingsLabel.Layout.Row = 5;
ui.BatchCommonSettingsLabel.Layout.Column = [1 2];

sweepPanel = uipanel(sideGrid, 'Title', 'Generate Sweep');
sweepPanel.Layout.Row = 2;
sweepGrid = uigridlayout(sweepPanel, [5, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 5), ...
    'Padding', [10, 8, 10, 8], ...
    'RowSpacing', 7);
rightLabel(sweepGrid, 'Base Name', 1, 1);
ui.BatchSweepBaseNameField = uieditfield(sweepGrid, 'text');
ui.BatchSweepBaseNameField.Layout.Row = 1;
ui.BatchSweepBaseNameField.Layout.Column = 2;
rightLabel(sweepGrid, 'Param A', 2, 1);
ui.BatchSweepParamADropDown = uidropdown(sweepGrid, ...
    'Items', batchSweepParameterItems());
ui.BatchSweepParamADropDown.Layout.Row = 2;
ui.BatchSweepParamADropDown.Layout.Column = 2;
rightLabel(sweepGrid, 'A Values', 3, 1);
ui.BatchSweepValuesAField = uieditfield(sweepGrid, 'text');
ui.BatchSweepValuesAField.Layout.Row = 3;
ui.BatchSweepValuesAField.Layout.Column = 2;
rightLabel(sweepGrid, 'Param B', 4, 1);
ui.BatchSweepParamBDropDown = uidropdown(sweepGrid, ...
    'Items', batchSweepParameterItems());
ui.BatchSweepParamBDropDown.Layout.Row = 4;
ui.BatchSweepParamBDropDown.Layout.Column = 2;
rightLabel(sweepGrid, 'B Values', 5, 1);
valuesAndButtonGrid = uigridlayout(sweepGrid, [1, 2], ...
    'ColumnWidth', {'1x', 110}, ...
    'RowHeight', {'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 6);
valuesAndButtonGrid.Layout.Row = 5;
valuesAndButtonGrid.Layout.Column = 2;
ui.BatchSweepValuesBField = uieditfield(valuesAndButtonGrid, 'text');
ui.BatchSweepValuesBField.Layout.Column = 1;
ui.BatchGenerateSweepButton = uibutton(valuesAndButtonGrid, 'Text', 'Generate', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('generateSweep'));
ui.BatchGenerateSweepButton.Layout.Column = 2;

runPanel = uipanel(sideGrid, 'Title', 'Run');
runPanel.Layout.Row = 3;
runGrid = uigridlayout(runPanel, [5, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 5), ...
    'Padding', [10, 8, 10, 8], ...
    'RowSpacing', 7);
ui.StartBatchImagingButton = uibutton(runGrid, 'Text', 'Start Batch', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) actionFcn('startBatch'));
ui.StartBatchImagingButton.Layout.Row = 1;
ui.StartBatchImagingButton.Layout.Column = [1 2];
ui.StopBatchImagingButton = uibutton(runGrid, 'Text', 'STOP Batch', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', stopFcn);
ui.StopBatchImagingButton.Layout.Row = 2;
ui.StopBatchImagingButton.Layout.Column = [1 2];
rightLabel(runGrid, 'Progress', 3, 1);
ui.BatchProgressField = uieditfield(runGrid, 'text', 'Editable', 'off');
ui.BatchProgressField.Layout.Row = 3;
ui.BatchProgressField.Layout.Column = 2;
rightLabel(runGrid, 'Current', 4, 1);
ui.BatchCurrentField = uieditfield(runGrid, 'text', 'Editable', 'off');
ui.BatchCurrentField.Layout.Row = 4;
ui.BatchCurrentField.Layout.Column = 2;
rightLabel(runGrid, 'Output', 5, 1);
ui.BatchOutputField = uieditfield(runGrid, 'text', 'Editable', 'off');
ui.BatchOutputField.Layout.Row = 5;
ui.BatchOutputField.Layout.Column = 2;

previewPanel = uipanel(sideGrid, 'Title', 'Selected Pattern Preview');
previewPanel.Layout.Row = 4;
previewGrid = uigridlayout(previewPanel, [1, 1], ...
    'Padding', [8, 8, 8, 8]);
ui.BatchPreviewAxes = uiaxes(previewGrid);
ui.BatchPreviewAxes.Layout.Row = 1;
ui.BatchPreviewAxes.Layout.Column = 1;
title(ui.BatchPreviewAxes, 'No selected pattern');
axis(ui.BatchPreviewAxes, 'image');
ui.BatchPreviewAxes.XTick = [];
ui.BatchPreviewAxes.YTick = [];
colormap(ui.BatchPreviewAxes, gray(256));
end

function labelHandle = rightLabel(parent, textValue, row, column)
labelHandle = uilabel(parent, 'Text', textValue, 'HorizontalAlignment', 'right');
labelHandle.Layout.Row = row;
labelHandle.Layout.Column = column;
end

function enableScrollingIfSupported(layoutHandle)
if isprop(layoutHandle, 'Scrollable')
    layoutHandle.Scrollable = 'on';
end
end
