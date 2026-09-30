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
cameraGrid = uigridlayout(cameraPanel, [15, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 15), ...
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

helpers.createRightLabel(cameraGrid, 'ROI', 9, 1);
imagingUi.FlirRoiModeDropDown = uidropdown(cameraGrid, ...
    'Items', {'Custom', 'Full sensor', 'Top-left quarter'}, ...
    'Value', 'Full sensor', ...
    'ValueChangedFcn', callbacks.flirRoiInputChanged);
imagingUi.FlirRoiModeDropDown.Layout.Row = 9;
imagingUi.FlirRoiModeDropDown.Layout.Column = 2;
imagingUi.FlirRoiModeDropDown.Tooltip = ...
    'Sensor area used by test capture, live view, and 3D imaging.';

roiFieldGrid = uigridlayout(cameraGrid, [2, 4], ...
    'ColumnWidth', {'fit', '1x', 'fit', '1x'}, ...
    'RowHeight', {'fit', 'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'RowSpacing', 8, ...
    'ColumnSpacing', 6);
roiFieldGrid.Layout.Row = 10;
roiFieldGrid.Layout.Column = [1 2];
roiFieldTooltip = 'Full-sensor pixels; snapped to the camera step size on Apply ROI.';
helpers.createRightLabel(roiFieldGrid, 'Offset X', 1, 1);
imagingUi.FlirRoiOffsetXField = createRoiField(roiFieldGrid, 1, 2, 0, roiFieldTooltip, callbacks.flirRoiInputChanged);
helpers.createRightLabel(roiFieldGrid, 'Offset Y', 1, 3);
imagingUi.FlirRoiOffsetYField = createRoiField(roiFieldGrid, 1, 4, 0, roiFieldTooltip, callbacks.flirRoiInputChanged);
helpers.createRightLabel(roiFieldGrid, 'Width', 2, 1);
imagingUi.FlirRoiWidthField = createRoiField(roiFieldGrid, 2, 2, 1, roiFieldTooltip, callbacks.flirRoiInputChanged);
helpers.createRightLabel(roiFieldGrid, 'Height', 2, 3);
imagingUi.FlirRoiHeightField = createRoiField(roiFieldGrid, 2, 4, 1, roiFieldTooltip, callbacks.flirRoiInputChanged);

roiButtonGrid = uigridlayout(cameraGrid, [1, 2], ...
    'ColumnWidth', {'1x', '1x'}, ...
    'RowHeight', {'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 8);
roiButtonGrid.Layout.Row = 11;
roiButtonGrid.Layout.Column = [1 2];
imagingUi.FlirCenterRoiButton = uibutton(roiButtonGrid, 'Text', 'Center ROI', ...
    'Tooltip', 'Center the ROI on the sensor, keeping its width and height.', ...
    'ButtonPushedFcn', callbacks.centerFlirRoi);
imagingUi.FlirCenterRoiButton.Layout.Row = 1;
imagingUi.FlirCenterRoiButton.Layout.Column = 1;
imagingUi.FlirApplyRoiButton = uibutton(roiButtonGrid, 'Text', 'Apply ROI', ...
    'Tooltip', 'Write the ROI to the camera and remember it for the next app start.', ...
    'ButtonPushedFcn', callbacks.applyFlirRoi);
imagingUi.FlirApplyRoiButton.Layout.Row = 1;
imagingUi.FlirApplyRoiButton.Layout.Column = 2;

imagingUi.FlirRoiInfoLabel = uilabel(cameraGrid, ...
    'Text', 'Connect FLIR to read the sensor size.', ...
    'WordWrap', 'on');
imagingUi.FlirRoiInfoLabel.Layout.Row = 12;
imagingUi.FlirRoiInfoLabel.Layout.Column = [1 2];

imagingUi.FlirTestCaptureButton = uibutton(cameraGrid, 'Text', 'Test Capture', ...
    'ButtonPushedFcn', callbacks.testFlirCapture);
imagingUi.FlirTestCaptureButton.Layout.Row = 13;
imagingUi.FlirTestCaptureButton.Layout.Column = [1 2];

imagingUi.OpenFlirLiveWindowButton = uibutton(cameraGrid, 'Text', 'Live FLIR...', ...
    'ButtonPushedFcn', callbacks.openFlirLiveWindow);
imagingUi.OpenFlirLiveWindowButton.Layout.Row = 14;
imagingUi.OpenFlirLiveWindowButton.Layout.Column = [1 2];

cameraNoteLabel = uilabel(cameraGrid, ...
    'Text', 'Close SpinView before connecting; the FLIR camera is used exclusively here.');
cameraNoteLabel.Layout.Row = 15;
cameraNoteLabel.Layout.Column = [1 2];

scanPanel = uipanel(controlsGrid, 'Title', 'Z Stack');
scanPanel.Layout.Row = 1;
scanPanel.Layout.Column = 3;
scanGrid = uigridlayout(scanPanel, [17, 2], ...
    'ColumnWidth', {120, '1x'}, ...
    'RowHeight', repmat({'fit'}, 1, 17), ...
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

imagingUi.ImagingAutoExposureCheckBox = uicheckbox(scanGrid, ...
    'Text', 'Auto exposure scout', ...
    'ValueChangedFcn', callbacks.autoExposureChanged);
imagingUi.ImagingAutoExposureCheckBox.Layout.Row = 8;
imagingUi.ImagingAutoExposureCheckBox.Layout.Column = [1 2];
imagingUi.ImagingAutoExposureCheckBox.Tooltip = ...
    'Before the stack, sample evenly spaced Z planes and set one exposure for the whole stack.';

helpers.createRightLabel(scanGrid, 'Scout Z Samples', 9, 1);
imagingUi.ImagingAutoExposureSamplesField = uieditfield(scanGrid, 'numeric');
imagingUi.ImagingAutoExposureSamplesField.Layout.Row = 9;
imagingUi.ImagingAutoExposureSamplesField.Layout.Column = 2;

helpers.createRightLabel(scanGrid, 'Safety Factor', 10, 1);
imagingUi.ImagingAutoExposureSafetyFactorField = uieditfield(scanGrid, 'numeric', ...
    'Limits', [0, Inf], ...
    'LowerLimitInclusive', 'off', ...
    'ValueChangedFcn', callbacks.autoExposureSafetyFactorChanged);
imagingUi.ImagingAutoExposureSafetyFactorField.Layout.Row = 10;
imagingUi.ImagingAutoExposureSafetyFactorField.Layout.Column = 2;
imagingUi.ImagingAutoExposureSafetyFactorField.Tooltip = ...
    ['Multiplier for the estimated no-clip exposure. 1 puts the brightest sampled pixel ', ...
    'at full scale; above 1 it saturates.'];

helpers.createRightLabel(scanGrid, 'Prefix', 11, 1);
imagingUi.ImagingPrefixField = uieditfield(scanGrid, 'text');
imagingUi.ImagingPrefixField.Layout.Row = 11;
imagingUi.ImagingPrefixField.Layout.Column = 2;

helpers.createRightLabel(scanGrid, 'Folder', 12, 1);
imagingUi.ImagingFolderField = uieditfield(scanGrid, 'text');
imagingUi.ImagingFolderField.Layout.Row = 12;
imagingUi.ImagingFolderField.Layout.Column = 2;

imagingUi.ImagingBrowseFolderButton = uibutton(scanGrid, 'Text', 'Browse Folder', ...
    'ButtonPushedFcn', callbacks.browseImagingFolder);
imagingUi.ImagingBrowseFolderButton.Layout.Row = 13;
imagingUi.ImagingBrowseFolderButton.Layout.Column = [1 2];

imagingEndpointGrid = uigridlayout(scanGrid, [1, 2], ...
    'ColumnWidth', {'1x', '1x'}, ...
    'RowHeight', {'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 8);
imagingEndpointGrid.Layout.Row = 14;
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
imagingUi.Start3DImagingButton.Layout.Row = 15;
imagingUi.Start3DImagingButton.Layout.Column = [1 2];

imagingUi.Stop3DImagingButton = uibutton(scanGrid, 'Text', 'STOP Imaging', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', callbacks.stopRequested);
imagingUi.Stop3DImagingButton.Layout.Row = 16;
imagingUi.Stop3DImagingButton.Layout.Column = [1 2];

stackNoteLabel = uilabel(scanGrid, ...
    'Text', 'Images are saved as a multi-page TIFF stack with a metadata.csv file in a timestamped run folder.');
stackNoteLabel.Layout.Row = 17;
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

function field = createRoiField(parent, row, column, minValue, tooltip, valueChangedFcn)
field = uieditfield(parent, 'numeric', ...
    'Limits', [minValue, Inf], ...
    'RoundFractionalValues', 'on', ...
    'ValueDisplayFormat', '%.0f', ...
    'Value', minValue, ...
    'Tooltip', tooltip, ...
    'ValueChangedFcn', valueChangedFcn);
field.Layout.Row = row;
field.Layout.Column = column;
end
