function liveUi = lw_build_flir_live_window(ownerFigure, callbacks, helpers, options)
%LW_BUILD_FLIR_LIVE_WINDOW Build the FLIR live view window.

liveUi = struct();

livePosition = [160, 100, 980, 680];
try
    mainPosition = ownerFigure.Position;
    livePosition = [mainPosition(1) + 80, mainPosition(2) + 60, 980, 680];
catch
end

liveUi.FlirLiveFigure = uifigure( ...
    'Name', 'Live FLIR', ...
    'Position', livePosition, ...
    'CloseRequestFcn', callbacks.closeWindow);

liveGrid = uigridlayout(liveUi.FlirLiveFigure, [1, 2], ...
    'ColumnWidth', {270, '1x'}, ...
    'Padding', [10, 10, 10, 10], ...
    'ColumnSpacing', 10);

controlsPanel = uipanel(liveGrid, 'Title', 'Live Controls');
controlsPanel.Layout.Row = 1;
controlsPanel.Layout.Column = 1;
controlsGrid = uigridlayout(controlsPanel, [14, 2], ...
    'ColumnWidth', {105, '1x'}, ...
    'RowHeight', [repmat({'fit'}, 1, 13), {'1x'}], ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(controlsGrid);

helpers.createRightLabel(controlsGrid, 'Status', 1, 1);
liveUi.FlirLiveStatusLabel = uilabel(controlsGrid, 'Text', 'Stopped');
liveUi.FlirLiveStatusLabel.Layout.Row = 1;
liveUi.FlirLiveStatusLabel.Layout.Column = 2;

helpers.createRightLabel(controlsGrid, 'Camera', 2, 1);
liveUi.FlirLiveCameraLabel = uilabel(controlsGrid, 'Text', options.selectedCameraLabel);
liveUi.FlirLiveCameraLabel.Layout.Row = 2;
liveUi.FlirLiveCameraLabel.Layout.Column = 2;

helpers.createRightLabel(controlsGrid, 'Current Exp', 3, 1);
liveUi.FlirLiveCurrentExposureLabel = uilabel(controlsGrid, 'Text', '-');
liveUi.FlirLiveCurrentExposureLabel.Layout.Row = 3;
liveUi.FlirLiveCurrentExposureLabel.Layout.Column = 2;

helpers.createRightLabel(controlsGrid, 'Current Gain', 4, 1);
liveUi.FlirLiveCurrentGainLabel = uilabel(controlsGrid, 'Text', '-');
liveUi.FlirLiveCurrentGainLabel.Layout.Row = 4;
liveUi.FlirLiveCurrentGainLabel.Layout.Column = 2;

liveUi.FlirLiveButton = uibutton(controlsGrid, ...
    'Text', 'Start Live', ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', callbacks.toggleLive);
liveUi.FlirLiveButton.Layout.Row = 5;
liveUi.FlirLiveButton.Layout.Column = [1 2];

helpers.createRightLabel(controlsGrid, 'Exposure (us)', 6, 1);
liveUi.FlirLiveExposureField = uieditfield(controlsGrid, 'numeric');
liveUi.FlirLiveExposureField.Layout.Row = 6;
liveUi.FlirLiveExposureField.Layout.Column = 2;

liveUi.FlirLiveApplyExposureButton = uibutton(controlsGrid, ...
    'Text', 'Apply Exposure', ...
    'ButtonPushedFcn', callbacks.applyExposure);
liveUi.FlirLiveApplyExposureButton.Layout.Row = 7;
liveUi.FlirLiveApplyExposureButton.Layout.Column = [1 2];

helpers.createRightLabel(controlsGrid, 'Gain (dB)', 8, 1);
liveUi.FlirLiveGainField = uieditfield(controlsGrid, 'numeric');
liveUi.FlirLiveGainField.Layout.Row = 8;
liveUi.FlirLiveGainField.Layout.Column = 2;

liveUi.FlirLiveApplyGainButton = uibutton(controlsGrid, ...
    'Text', 'Apply Gain', ...
    'ButtonPushedFcn', callbacks.applyGain);
liveUi.FlirLiveApplyGainButton.Layout.Row = 9;
liveUi.FlirLiveApplyGainButton.Layout.Column = [1 2];

helpers.createRightLabel(controlsGrid, 'Timeout (ms)', 10, 1);
liveUi.FlirLiveTimeoutField = uieditfield(controlsGrid, 'numeric', ...
    'ValueChangedFcn', @(source, ~) callbacks.timeoutChanged(source.Value));
liveUi.FlirLiveTimeoutField.Layout.Row = 10;
liveUi.FlirLiveTimeoutField.Layout.Column = 2;

helpers.createRightLabel(controlsGrid, 'Period (s)', 11, 1);
liveUi.FlirLivePeriodField = uieditfield(controlsGrid, 'numeric', ...
    'ValueChangedFcn', @(source, ~) callbacks.periodChanged(source.Value));
liveUi.FlirLivePeriodField.Layout.Row = 11;
liveUi.FlirLivePeriodField.Layout.Column = 2;

liveUi.FlirLiveMarkerCheckBox = uicheckbox(controlsGrid, ...
    'Text', 'Mark saturation/zero', ...
    'Value', false, ...
    'Tooltip', 'Show saturated pixels in red and zero-value pixels in blue', ...
    'ValueChangedFcn', callbacks.markerChanged);
liveUi.FlirLiveMarkerCheckBox.Layout.Row = 12;
liveUi.FlirLiveMarkerCheckBox.Layout.Column = [1 2];

closeButton = uibutton(controlsGrid, ...
    'Text', 'Close Window', ...
    'ButtonPushedFcn', callbacks.closeWindow);
closeButton.Layout.Row = 13;
closeButton.Layout.Column = [1 2];

framePanel = uipanel(liveGrid, 'Title', 'Live FLIR Frame');
framePanel.Layout.Row = 1;
framePanel.Layout.Column = 2;
frameGrid = uigridlayout(framePanel, [1, 1], ...
    'Padding', [8, 8, 8, 8]);
liveUi.FlirLiveAxes = uiaxes(frameGrid);
liveUi.FlirLiveAxes.Layout.Row = 1;
liveUi.FlirLiveAxes.Layout.Column = 1;
title(liveUi.FlirLiveAxes, 'Live stopped');
liveUi.FlirLiveAxes.XTick = [];
liveUi.FlirLiveAxes.YTick = [];
axis(liveUi.FlirLiveAxes, 'image');
end
