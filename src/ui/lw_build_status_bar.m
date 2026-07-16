function statusUi = lw_build_status_bar(parent, callbacks)
%LW_BUILD_STATUS_BAR Build the top status bar and return its UI handles.

statusUi = struct();

barGrid = uigridlayout(parent, [2, 3], ...
    'ColumnWidth', {'1x', 650, 110}, ...
    'RowHeight', {'1x', '1x'}, ...
    'Padding', [8, 5, 8, 5], ...
    'RowSpacing', 4, ...
    'ColumnSpacing', 12);
barGrid.Layout.Row = 1;

connectionGrid = uigridlayout(barGrid, [1, 6], ...
    'ColumnWidth', {22, 'fit', 22, 'fit', 22, 'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 7);
connectionGrid.Layout.Row = 1;
connectionGrid.Layout.Column = 1;

statusUi.StageLamp = uilamp(connectionGrid, 'Color', [0.85, 0.2, 0.2]);
statusUi.StageLamp.Layout.Row = 1; statusUi.StageLamp.Layout.Column = 1;
statusUi.StageStatusLabel = uilabel(connectionGrid, 'Text', 'Stages: Disconnected');
statusUi.StageStatusLabel.Layout.Row = 1; statusUi.StageStatusLabel.Layout.Column = 2;

statusUi.DAQLamp = uilamp(connectionGrid, 'Color', [0.85, 0.2, 0.2]);
statusUi.DAQLamp.Layout.Row = 1; statusUi.DAQLamp.Layout.Column = 3;
statusUi.DAQStatusLabel = uilabel(connectionGrid, 'Text', 'DAQ: Disconnected');
statusUi.DAQStatusLabel.Layout.Row = 1; statusUi.DAQStatusLabel.Layout.Column = 4;

statusUi.CarbideLamp = uilamp(connectionGrid, 'Color', [0.85, 0.2, 0.2]);
statusUi.CarbideLamp.Layout.Row = 1; statusUi.CarbideLamp.Layout.Column = 5;
statusUi.CarbideStatusBarLabel = uilabel(connectionGrid, 'Text', 'Carbide: Disconnected');
statusUi.CarbideStatusBarLabel.Layout.Row = 1; statusUi.CarbideStatusBarLabel.Layout.Column = 6;

runtimeGrid = uigridlayout(barGrid, [1, 4], ...
    'ColumnWidth', {22, 'fit', 22, 'fit'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 7);
runtimeGrid.Layout.Row = 2;
runtimeGrid.Layout.Column = 1;

statusUi.CarbideStateLamp = uilamp(runtimeGrid, 'Color', [0.85, 0.2, 0.2]);
statusUi.CarbideStateLamp.Layout.Row = 1; statusUi.CarbideStateLamp.Layout.Column = 1;
statusUi.CarbideStateStatusLabel = uilabel(runtimeGrid, 'Text', 'Carbide State: -');
statusUi.CarbideStateStatusLabel.Layout.Row = 1; statusUi.CarbideStateStatusLabel.Layout.Column = 2;

statusUi.CarbideShutterLamp = uilamp(runtimeGrid, 'Color', [0.5, 0.5, 0.5]);
statusUi.CarbideShutterLamp.Layout.Row = 1; statusUi.CarbideShutterLamp.Layout.Column = 3;
statusUi.CarbideShutterStatusLabel = uilabel(runtimeGrid, 'Text', 'Shutter: -');
statusUi.CarbideShutterStatusLabel.Layout.Row = 1; statusUi.CarbideShutterStatusLabel.Layout.Column = 4;

metricsGrid = uigridlayout(barGrid, [1, 7], ...
    'ColumnWidth', {22, 'fit', 22, 'fit', 105, 150, '1x'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 12);
metricsGrid.Layout.Row = [1 2];
metricsGrid.Layout.Column = 2;

statusUi.BusyLamp = uilamp(metricsGrid, 'Color', [0.2, 0.7, 0.2]);
statusUi.BusyLamp.Layout.Row = 1; statusUi.BusyLamp.Layout.Column = 1;
statusUi.BusyStatusLabel = uilabel(metricsGrid, 'Text', 'Idle');
statusUi.BusyStatusLabel.Layout.Row = 1; statusUi.BusyStatusLabel.Layout.Column = 2;
statusUi.StatusLaserStateLamp = uilamp(metricsGrid, 'Color', [0.85, 0.2, 0.2]);
statusUi.StatusLaserStateLamp.Layout.Row = 1; statusUi.StatusLaserStateLamp.Layout.Column = 3;
statusUi.StatusLaserStateLabel = uilabel(metricsGrid, 'Text', 'Laser State: Off');
statusUi.StatusLaserStateLabel.Layout.Row = 1; statusUi.StatusLaserStateLabel.Layout.Column = 4;
statusUi.CarbidePowerStatusLabel = uilabel(metricsGrid, 'Text', 'Power: -');
statusUi.CarbidePowerStatusLabel.Layout.Row = 1; statusUi.CarbidePowerStatusLabel.Layout.Column = 5;
statusUi.CarbidePulseEnergyStatusLabel = uilabel(metricsGrid, 'Text', 'Pulse Energy: -');
statusUi.CarbidePulseEnergyStatusLabel.Layout.Row = 1; statusUi.CarbidePulseEnergyStatusLabel.Layout.Column = 6;
statusUi.CurrentXYZLabel = uilabel(metricsGrid, 'Text', 'X: -, Y: -, Z: -');
statusUi.CurrentXYZLabel.Layout.Row = 1; statusUi.CurrentXYZLabel.Layout.Column = 7;

statusUi.GlobalStopButton = uibutton(barGrid, 'Text', 'STOP', ...
    'BackgroundColor', [0.95, 0.25, 0.25], ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', callbacks.stopRequested);
statusUi.GlobalStopButton.Layout.Row = [1 2];
statusUi.GlobalStopButton.Layout.Column = 3;
statusUi.GlobalStopButton.Tooltip = 'Request stop and force the laser outputs off';
end
