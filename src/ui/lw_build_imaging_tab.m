function imagingUi = lw_build_imaging_tab(tab, callbacks, helpers)
%LW_BUILD_IMAGING_TAB Build the 3D imaging tab and return its UI handles.

imagingUi = struct();

grid = uigridlayout(tab, [3, 3], ...
    'ColumnWidth', {'1.05x', 6, '1.35x'}, ...
    'RowHeight', {'1.35x', 6, '0.65x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 3, ...
    'ColumnSpacing', 3);
helpers.createGridSplitter(grid, [1 3], 2, 'column', 1, 3);
helpers.createGridSplitter(grid, 2, 1, 'row', 1, 3);

controlsGrid = uigridlayout(grid, [1, 3], ...
    'ColumnWidth', {'0.95x', 6, '1.15x'}, ...
    'RowHeight', {'1x'}, ...
    'Padding', [0, 0, 0, 0], ...
    'RowSpacing', 0, ...
    'ColumnSpacing', 3);
controlsGrid.Layout.Row = 1;
controlsGrid.Layout.Column = 1;
helpers.createGridSplitter(controlsGrid, 1, 2, 'column', 1, 3);

cameraPanel = uipanel(controlsGrid, 'Title', 'FLIR Camera');
cameraPanel.Layout.Row = 1;
cameraPanel.Layout.Column = 1;
cameraGrid = uigridlayout(cameraPanel, [14, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 14), ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(cameraGrid);

helpers.createRightLabel(cameraGrid, 'Status', 1, 1);
imagingUi.FlirStatusLabel = uilabel(cameraGrid, 'Text', 'Disconnected');
imagingUi.FlirStatusLabel.Layout.Row = 1;
imagingUi.FlirStatusLabel.Layout.Column = 2;

imagingUi.FlirRefreshButton = uibutton(cameraGrid, 'Text', 'Refresh FLIR', ...
    'ButtonPushedFcn', callbacks.refreshFlirDevices);
imagingUi.FlirRefreshButton.Layout.Row = 2;
imagingUi.FlirRefreshButton.Layout.Column = [1 2];

helpers.createRightLabel(cameraGrid, 'Camera', 3, 1);
imagingUi.FlirDeviceDropDown = uidropdown(cameraGrid, ...
    'Items', {'No camera detected'}, ...
    'Value', 'No camera detected');
imagingUi.FlirDeviceDropDown.Layout.Row = 3;
imagingUi.FlirDeviceDropDown.Layout.Column = 2;

imagingUi.FlirConnectButton = uibutton(cameraGrid, 'Text', 'Connect', ...
    'ButtonPushedFcn', callbacks.connectFlir);
imagingUi.FlirConnectButton.Layout.Row = 4;
imagingUi.FlirConnectButton.Layout.Column = 1;
imagingUi.FlirDisconnectButton = uibutton(cameraGrid, 'Text', 'Disconnect', ...
    'ButtonPushedFcn', callbacks.disconnectFlir);
imagingUi.FlirDisconnectButton.Layout.Row = 4;
imagingUi.FlirDisconnectButton.Layout.Column = 2;

helpers.createRightLabel(cameraGrid, 'Exposure (us)', 5, 1);
imagingUi.FlirExposureField = uieditfield(cameraGrid, 'numeric');
imagingUi.FlirExposureField.Layout.Row = 5;
imagingUi.FlirExposureField.Layout.Column = 2;

imagingUi.FlirApplyExposureButton = uibutton(cameraGrid, 'Text', 'Apply Exposure', ...
    'ButtonPushedFcn', callbacks.applyFlirExposure);
imagingUi.FlirApplyExposureButton.Layout.Row = 6;
imagingUi.FlirApplyExposureButton.Layout.Column = [1 2];

helpers.createRightLabel(cameraGrid, 'Gain (dB)', 7, 1);
imagingUi.FlirGainField = uieditfield(cameraGrid, 'numeric');
imagingUi.FlirGainField.Layout.Row = 7;
imagingUi.FlirGainField.Layout.Column = 2;

imagingUi.FlirApplyGainButton = uibutton(cameraGrid, 'Text', 'Apply Gain', ...
    'ButtonPushedFcn', callbacks.applyFlirGain);
imagingUi.FlirApplyGainButton.Layout.Row = 8;
imagingUi.FlirApplyGainButton.Layout.Column = [1 2];

imagingUi.FlirTestCaptureButton = uibutton(cameraGrid, 'Text', 'Test Capture', ...
    'ButtonPushedFcn', callbacks.testFlirCapture);
imagingUi.FlirTestCaptureButton.Layout.Row = 9;
imagingUi.FlirTestCaptureButton.Layout.Column = [1 2];

imagingUi.OpenFlirLiveWindowButton = uibutton(cameraGrid, 'Text', 'Live FLIR...', ...
    'ButtonPushedFcn', callbacks.openFlirLiveWindow);
imagingUi.OpenFlirLiveWindowButton.Layout.Row = 10;
imagingUi.OpenFlirLiveWindowButton.Layout.Column = [1 2];

imagingUi.ImagingAutoExposureCheckBox = uicheckbox(cameraGrid, ...
    'Text', 'Auto exposure scout', ...
    'ValueChangedFcn', callbacks.autoExposureChanged);
imagingUi.ImagingAutoExposureCheckBox.Layout.Row = 11;
imagingUi.ImagingAutoExposureCheckBox.Layout.Column = [1 2];
imagingUi.ImagingAutoExposureCheckBox.Tooltip = ...
    'Sample evenly spaced Z planes and set the stack exposure from the no-clip estimate.';

helpers.createRightLabel(cameraGrid, 'Scout Z Samples', 12, 1);
imagingUi.ImagingAutoExposureSamplesField = uieditfield(cameraGrid, 'numeric');
imagingUi.ImagingAutoExposureSamplesField.Layout.Row = 12;
imagingUi.ImagingAutoExposureSamplesField.Layout.Column = 2;

helpers.createRightLabel(cameraGrid, 'Safety Factor', 13, 1);
imagingUi.ImagingAutoExposureSafetyFactorField = uieditfield(cameraGrid, 'numeric');
imagingUi.ImagingAutoExposureSafetyFactorField.Layout.Row = 13;
imagingUi.ImagingAutoExposureSafetyFactorField.Layout.Column = 2;
imagingUi.ImagingAutoExposureSafetyFactorField.Tooltip = ...
    'Multiplier for the estimated no-clip exposure; use a value between 0 and 1.';

cameraNoteLabel = uilabel(cameraGrid, ...
    'Text', 'Close SpinView before connecting; the FLIR camera is used exclusively here.');
cameraNoteLabel.Layout.Row = 14;
cameraNoteLabel.Layout.Column = [1 2];

scanPanel = uipanel(controlsGrid, 'Title', 'Z Stack');
scanPanel.Layout.Row = 1;
scanPanel.Layout.Column = 3;
scanGrid = uigridlayout(scanPanel, [14, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 14), ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(scanGrid);

helpers.createRightLabel(scanGrid, 'X', 1, 1);
imagingUi.ImagingXField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingXField.Layout.Row = 1;
imagingUi.ImagingXField.Layout.Column = 2;
helpers.createRightLabel(scanGrid, 'Y', 2, 1);
imagingUi.ImagingYField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingYField.Layout.Row = 2;
imagingUi.ImagingYField.Layout.Column = 2;

helpers.createRightLabel(scanGrid, 'Z Start', 3, 1);
imagingUi.ImagingZStartField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingZStartField.Layout.Row = 3;
imagingUi.ImagingZStartField.Layout.Column = 2;
helpers.createRightLabel(scanGrid, 'Z End', 4, 1);
imagingUi.ImagingZEndField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingZEndField.Layout.Row = 4;
imagingUi.ImagingZEndField.Layout.Column = 2;

helpers.createRightLabel(scanGrid, 'Z Step', 5, 1);
imagingUi.ImagingZStepField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingZStepField.Layout.Row = 5;
imagingUi.ImagingZStepField.Layout.Column = 2;
helpers.createRightLabel(scanGrid, 'Settle (s)', 6, 1);
imagingUi.ImagingSettleField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingSettleField.Layout.Row = 6;
imagingUi.ImagingSettleField.Layout.Column = 2;

helpers.createRightLabel(scanGrid, 'Timeout (ms)', 7, 1);
imagingUi.ImagingTimeoutField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingTimeoutField.Layout.Row = 7;
imagingUi.ImagingTimeoutField.Layout.Column = 2;
helpers.createRightLabel(scanGrid, 'Prefix', 8, 1);
imagingUi.ImagingPrefixField = uieditfield(scanGrid, 'text');
imagingUi.ImagingPrefixField.Layout.Row = 8;
imagingUi.ImagingPrefixField.Layout.Column = 2;

helpers.createRightLabel(scanGrid, 'Folder', 9, 1);
imagingUi.ImagingFolderField = uieditfield(scanGrid, 'text');
imagingUi.ImagingFolderField.Layout.Row = 9;
imagingUi.ImagingFolderField.Layout.Column = 2;

imagingUi.ImagingBrowseFolderButton = uibutton(scanGrid, 'Text', 'Browse Folder', ...
    'ButtonPushedFcn', callbacks.browseImagingFolder);
imagingUi.ImagingBrowseFolderButton.Layout.Row = 10;
imagingUi.ImagingBrowseFolderButton.Layout.Column = [1 2];

imagingEndpointGrid = uigridlayout(scanGrid, [1, 2], ...
    'ColumnWidth', {'1x', '1x'}, ...
    'RowHeight', {'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 8);
imagingEndpointGrid.Layout.Row = 11;
imagingEndpointGrid.Layout.Column = [1 2];
imagingUi.ImagingSetEndButton = uibutton(imagingEndpointGrid, 'Text', 'Set as End', ...
    'ButtonPushedFcn', callbacks.setCurrentImagingEnd);
imagingUi.ImagingSetEndButton.Layout.Row = 1;
imagingUi.ImagingSetEndButton.Layout.Column = 1;
imagingUi.ImagingSetStartButton = uibutton(imagingEndpointGrid, 'Text', 'Set as Start', ...
    'ButtonPushedFcn', callbacks.setCurrentImagingStart);
imagingUi.ImagingSetStartButton.Layout.Row = 1;
imagingUi.ImagingSetStartButton.Layout.Column = 2;

imagingUi.Start3DImagingButton = uibutton(scanGrid, 'Text', 'Start 3D Imaging', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', callbacks.start3DImaging);
imagingUi.Start3DImagingButton.Layout.Row = 12;
imagingUi.Start3DImagingButton.Layout.Column = [1 2];

imagingUi.Stop3DImagingButton = uibutton(scanGrid, 'Text', 'STOP Imaging', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', callbacks.stopRequested);
imagingUi.Stop3DImagingButton.Layout.Row = 13;
imagingUi.Stop3DImagingButton.Layout.Column = [1 2];

stackNoteLabel = uilabel(scanGrid, ...
    'Text', 'Images are saved as a multi-page TIFF stack with a metadata.csv file in a timestamped run folder.');
stackNoteLabel.Layout.Row = 14;
stackNoteLabel.Layout.Column = [1 2];

statusPanel = uipanel(grid, 'Title', 'Imaging Status');
statusPanel.Layout.Row = 3;
statusPanel.Layout.Column = 1;
statusGrid = uigridlayout(statusPanel, [4, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', '1x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(statusGrid);
helpers.createRightLabel(statusGrid, 'Progress', 1, 1);
imagingUi.ImagingProgressField = uieditfield(statusGrid, 'text', 'Editable', 'off');
imagingUi.ImagingProgressField.Layout.Row = 1;
imagingUi.ImagingProgressField.Layout.Column = 2;
helpers.createRightLabel(statusGrid, 'Current', 2, 1);
imagingUi.ImagingCurrentField = uieditfield(statusGrid, 'text', 'Editable', 'off');
imagingUi.ImagingCurrentField.Layout.Row = 2;
imagingUi.ImagingCurrentField.Layout.Column = 2;
helpers.createRightLabel(statusGrid, 'Output', 3, 1);
imagingUi.ImagingOutputField = uieditfield(statusGrid, 'text', 'Editable', 'off');
imagingUi.ImagingOutputField.Layout.Row = 3;
imagingUi.ImagingOutputField.Layout.Column = 2;
imagingStopNoteLabel = uilabel(statusGrid, ...
    'Text', 'Global STOP stops the current stage move, turns laser outputs off, and ends the imaging loop.');
imagingStopNoteLabel.Layout.Row = 4;
imagingStopNoteLabel.Layout.Column = [1 2];

previewPanel = uipanel(grid, 'Title', 'Latest Captured FLIR Frame');
previewPanel.Layout.Row = [1 3];
previewPanel.Layout.Column = 3;
previewGrid = uigridlayout(previewPanel, [1, 1], ...
    'Padding', [8, 8, 8, 8]);

imagingUi.ImagingAxes = uiaxes(previewGrid);
imagingUi.ImagingAxes.Layout.Row = 1;
imagingUi.ImagingAxes.Layout.Column = 1;
title(imagingUi.ImagingAxes, 'No frame captured');
imagingUi.ImagingAxes.XTick = [];
imagingUi.ImagingAxes.YTick = [];
end
