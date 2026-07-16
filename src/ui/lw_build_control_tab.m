function controlUi = lw_build_control_tab(tab, callbacks, helpers)
%LW_BUILD_CONTROL_TAB Build the connection, motion, laser, and Carbide controls.

controlUi = struct();

grid = uigridlayout(tab, [3, 5], ...
    'ColumnWidth', {'0.82x', 6, '1x', 6, '1.15x'}, ...
    'RowHeight', {'1x', 6, '1x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 3, ...
    'ColumnSpacing', 3);
helpers.createGridSplitter(grid, 1, 2, 'column', 1, 3);
helpers.createGridSplitter(grid, 1, 4, 'column', 3, 5);
helpers.createGridSplitter(grid, 3, 4, 'column', 3, 5);
helpers.createGridSplitter(grid, 2, [1 5], 'row', 1, 3);

connectionPanel = uipanel(grid, 'Title', 'Connection');
connectionPanel.Layout.Row = 1;
connectionPanel.Layout.Column = 1;
connectionGrid = uigridlayout(connectionPanel, [12, 1], ...
    'RowHeight', repmat({'fit'}, 1, 12), ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(connectionGrid);
controlUi.ConnectAllButton = uibutton(connectionGrid, 'Text', 'Connect All', ...
    'ButtonPushedFcn', callbacks.connectAll);
controlUi.ConnectStagesButton = uibutton(connectionGrid, 'Text', 'Connect Stages', ...
    'ButtonPushedFcn', callbacks.connectStages);
controlUi.ConnectDAQButton = uibutton(connectionGrid, 'Text', 'Connect DAQ', ...
    'ButtonPushedFcn', callbacks.connectDAQ);
controlUi.ConnectCarbideButton = uibutton(connectionGrid, 'Text', 'Connect Carbide', ...
    'ButtonPushedFcn', callbacks.connectCarbide);
controlUi.DisconnectCarbideButton = uibutton(connectionGrid, 'Text', 'Disconnect Carbide', ...
    'ButtonPushedFcn', callbacks.disconnectCarbide);
controlUi.DisconnectButton = uibutton(connectionGrid, 'Text', 'Disconnect', ...
    'ButtonPushedFcn', callbacks.disconnect);
controlUi.HomeButton = uibutton(connectionGrid, 'Text', 'Home', ...
    'ButtonPushedFcn', callbacks.homeStages);
controlUi.ConnectionStagesLabel = uilabel(connectionGrid, 'Text', 'Stages: Disconnected');
controlUi.ConnectionDAQLabel = uilabel(connectionGrid, 'Text', 'DAQ: Disconnected');
controlUi.ConnectionCarbideLabel = uilabel(connectionGrid, 'Text', 'Carbide: Disconnected');
controlUi.ConnectionBusyLabel = uilabel(connectionGrid, 'Text', 'Busy: No');
controlUi.ConnectionStopLabel = uilabel(connectionGrid, 'Text', 'Stop Flag: False');

levelingPanel = uipanel(grid, 'Title', 'Surface Leveling');
levelingPanel.Layout.Row = 1;
levelingPanel.Layout.Column = 3;
levelingGrid = uigridlayout(levelingPanel, [8, 2], ...
    'ColumnWidth', {88, '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'}, ...
    'Padding', [10, 10, 10, 10], ...
    'RowSpacing', 5, ...
    'ColumnSpacing', 8);
helpers.enableScrolling(levelingGrid);

controlUi.LevelingModeLabel = uilabel(levelingGrid, 'Text', '3-Point Plane');
controlUi.LevelingModeLabel.Layout.Row = 1;
controlUi.LevelingModeLabel.Layout.Column = [1 2];

controlUi.Mark0Button = uibutton(levelingGrid, 'Text', 'Point A', ...
    'ButtonPushedFcn', @(~, ~) callbacks.captureMark('mark0'));
controlUi.Mark0Button.Layout.Row = 2;
controlUi.Mark0Button.Layout.Column = 1;
controlUi.PointAStatusLabel = uilabel(levelingGrid, 'Text', 'Point A: Missing');
controlUi.PointAStatusLabel.Layout.Row = 2;
controlUi.PointAStatusLabel.Layout.Column = 2;

controlUi.Mark1Button = uibutton(levelingGrid, 'Text', 'Point B', ...
    'ButtonPushedFcn', @(~, ~) callbacks.captureMark('mark1'));
controlUi.Mark1Button.Layout.Row = 3;
controlUi.Mark1Button.Layout.Column = 1;
controlUi.PointBStatusLabel = uilabel(levelingGrid, 'Text', 'Point B: Missing');
controlUi.PointBStatusLabel.Layout.Row = 3;
controlUi.PointBStatusLabel.Layout.Column = 2;

controlUi.Mark2Button = uibutton(levelingGrid, 'Text', 'Point C', ...
    'ButtonPushedFcn', @(~, ~) callbacks.captureMark('mark2'));
controlUi.Mark2Button.Layout.Row = 4;
controlUi.Mark2Button.Layout.Column = 1;
controlUi.PointCStatusLabel = uilabel(levelingGrid, 'Text', 'Point C: Missing');
controlUi.PointCStatusLabel.Layout.Row = 4;
controlUi.PointCStatusLabel.Layout.Column = 2;

controlUi.LevelTiltXNameLabel = uilabel(levelingGrid, 'Text', 'Tilt X');
controlUi.LevelTiltXNameLabel.Layout.Row = 5;
controlUi.LevelTiltXNameLabel.Layout.Column = 1;
controlUi.LevelTiltXValueLabel = uilabel(levelingGrid, 'Text', '-');
controlUi.LevelTiltXValueLabel.Layout.Row = 5;
controlUi.LevelTiltXValueLabel.Layout.Column = 2;

controlUi.LevelTiltYNameLabel = uilabel(levelingGrid, 'Text', 'Tilt Y');
controlUi.LevelTiltYNameLabel.Layout.Row = 6;
controlUi.LevelTiltYNameLabel.Layout.Column = 1;
controlUi.LevelTiltYValueLabel = uilabel(levelingGrid, 'Text', '-');
controlUi.LevelTiltYValueLabel.Layout.Row = 6;
controlUi.LevelTiltYValueLabel.Layout.Column = 2;

controlUi.LevelZRangeNameLabel = uilabel(levelingGrid, 'Text', 'Z Range');
controlUi.LevelZRangeNameLabel.Layout.Row = 7;
controlUi.LevelZRangeNameLabel.Layout.Column = 1;
controlUi.LevelZRangeValueLabel = uilabel(levelingGrid, 'Text', '-');
controlUi.LevelZRangeValueLabel.Layout.Row = 7;
controlUi.LevelZRangeValueLabel.Layout.Column = 2;

controlUi.LevelingHintLabel = uilabel(levelingGrid, ...
    'Text', 'Use jog or absolute move to position the stage, then capture 3 focused points on the same surface. Point A/B/C define the plane, and leveling is applied relative to the current Start XY.', ...
    'WordWrap', 'on', ...
    'FontColor', [0.35, 0.35, 0.35]);
controlUi.LevelingHintLabel.Layout.Row = 8;
controlUi.LevelingHintLabel.Layout.Column = [1 2];

manualPanel = uipanel(grid, 'Title', 'Manual Motion');
manualPanel.Layout.Row = 3;
manualPanel.Layout.Column = [1 3];
manualOuterGrid = uigridlayout(manualPanel, [1, 5], ...
    'ColumnWidth', {'2.5x', 6, '1x', 6, '2.8x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'ColumnSpacing', 3);
helpers.enableScrolling(manualOuterGrid);
helpers.createGridSplitter(manualOuterGrid, 1, 2, 'column', 1, 3);
helpers.createGridSplitter(manualOuterGrid, 1, 4, 'column', 3, 5);

xyPanel = uipanel(manualOuterGrid, 'Title', 'XY Jog');
xyPanel.Layout.Row = 1;
xyPanel.Layout.Column = 1;
xyOuterGrid = uigridlayout(xyPanel, [2, 1], ...
    'RowHeight', {24, '1x'}, ...
    'Padding', [8, 8, 8, 8], ...
    'RowSpacing', 8);
helpers.enableScrolling(xyOuterGrid);
uilabel(xyOuterGrid, 'Text', 'Use large buttons for XY positioning');
xyGrid = uigridlayout(xyOuterGrid, [3, 3], ...
    'ColumnWidth', {'1x', '1x', '1x'}, ...
    'RowHeight', {'1x', '1x', '1x'}, ...
    'Padding', [2, 2, 2, 2], ...
    'RowSpacing', 8, ...
    'ColumnSpacing', 8);
blank = uilabel(xyGrid, 'Text', '');
blank.Layout.Row = 1; blank.Layout.Column = 1;
controlUi.JogYPlusButton = uibutton(xyGrid, 'Text', 'Y+', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) callbacks.jog('y', +1));
controlUi.JogYPlusButton.Layout.Row = 1; controlUi.JogYPlusButton.Layout.Column = 2;
blank = uilabel(xyGrid, 'Text', '');
blank.Layout.Row = 1; blank.Layout.Column = 3;
controlUi.JogXMinusButton = uibutton(xyGrid, 'Text', 'X-', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) callbacks.jog('x', -1));
controlUi.JogXMinusButton.Layout.Row = 2; controlUi.JogXMinusButton.Layout.Column = 1;
blank = uilabel(xyGrid, 'Text', '');
blank.Layout.Row = 2; blank.Layout.Column = 2;
controlUi.JogXPlusButton = uibutton(xyGrid, 'Text', 'X+', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) callbacks.jog('x', +1));
controlUi.JogXPlusButton.Layout.Row = 2; controlUi.JogXPlusButton.Layout.Column = 3;
blank = uilabel(xyGrid, 'Text', '');
blank.Layout.Row = 3; blank.Layout.Column = 1;
controlUi.JogYMinusButton = uibutton(xyGrid, 'Text', 'Y-', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) callbacks.jog('y', -1));
controlUi.JogYMinusButton.Layout.Row = 3; controlUi.JogYMinusButton.Layout.Column = 2;
blank = uilabel(xyGrid, 'Text', '');
blank.Layout.Row = 3; blank.Layout.Column = 3;

zPanel = uipanel(manualOuterGrid, 'Title', 'Z Jog');
zPanel.Layout.Row = 1;
zPanel.Layout.Column = 3;
zGrid = uigridlayout(zPanel, [4, 1], ...
    'RowHeight', {24, '1x', '1x', 24}, ...
    'Padding', [8, 8, 8, 8], ...
    'RowSpacing', 8);
helpers.enableScrolling(zGrid);
uilabel(zGrid, 'Text', 'Z axis');
controlUi.JogZPlusButton = uibutton(zGrid, 'Text', 'Z+ (Far)', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) callbacks.jog('z', +1));
controlUi.JogZMinusButton = uibutton(zGrid, 'Text', 'Z- (Near)', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~, ~) callbacks.jog('z', -1));
uilabel(zGrid, 'Text', '');

paramsPanel = uipanel(manualOuterGrid, 'Title', 'Motion Parameters');
paramsPanel.Layout.Row = 1;
paramsPanel.Layout.Column = 5;
paramsGrid = uigridlayout(paramsPanel, [4, 4], ...
    'ColumnWidth', {55, '1x', '1x', '1x'}, ...
    'RowHeight', {24, '1x', '1x', '1x'}, ...
    'Padding', [8, 8, 8, 8], ...
    'RowSpacing', 8, ...
    'ColumnSpacing', 8);
helpers.enableScrolling(paramsGrid);
uilabel(paramsGrid, 'Text', '');
uilabel(paramsGrid, 'Text', 'Step', 'HorizontalAlignment', 'center');
uilabel(paramsGrid, 'Text', 'Vel (mm/s)', 'HorizontalAlignment', 'center');
uilabel(paramsGrid, 'Text', 'Acc (mm/s^2)', 'HorizontalAlignment', 'center');

uilabel(paramsGrid, 'Text', 'X', 'HorizontalAlignment', 'center');
controlUi.ManualStepXField = uieditfield(paramsGrid, 'numeric');
controlUi.ManualVelXField = uieditfield(paramsGrid, 'numeric');
controlUi.ManualAccXField = uieditfield(paramsGrid, 'numeric');

uilabel(paramsGrid, 'Text', 'Y', 'HorizontalAlignment', 'center');
controlUi.ManualStepYField = uieditfield(paramsGrid, 'numeric');
controlUi.ManualVelYField = uieditfield(paramsGrid, 'numeric');
controlUi.ManualAccYField = uieditfield(paramsGrid, 'numeric');

uilabel(paramsGrid, 'Text', 'Z', 'HorizontalAlignment', 'center');
controlUi.ManualStepZField = uieditfield(paramsGrid, 'numeric');
controlUi.ManualVelZField = uieditfield(paramsGrid, 'numeric');
controlUi.ManualAccZField = uieditfield(paramsGrid, 'numeric');

absolutePanel = uipanel(grid, 'Title', 'Absolute Move');
absolutePanel.Layout.Row = 1;
absolutePanel.Layout.Column = 5;
absoluteGrid = uigridlayout(absolutePanel, [7, 4], ...
    'ColumnWidth', {125, '1x', 130, '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 5);
helpers.enableScrolling(absoluteGrid);
helpers.createRightLabel(absoluteGrid, 'Target X', 1, 1);
controlUi.TargetXField = uieditfield(absoluteGrid, 'numeric');
controlUi.TargetXField.Layout.Row = 1; controlUi.TargetXField.Layout.Column = 2;
helpers.createRightLabel(absoluteGrid, 'Velocity X (mm/s)', 1, 3);
controlUi.AbsoluteVelXField = uieditfield(absoluteGrid, 'numeric');
controlUi.AbsoluteVelXField.Layout.Row = 1; controlUi.AbsoluteVelXField.Layout.Column = 4;
helpers.createRightLabel(absoluteGrid, 'Target Y', 2, 1);
controlUi.TargetYField = uieditfield(absoluteGrid, 'numeric');
controlUi.TargetYField.Layout.Row = 2; controlUi.TargetYField.Layout.Column = 2;
helpers.createRightLabel(absoluteGrid, 'Velocity Y (mm/s)', 2, 3);
controlUi.AbsoluteVelYField = uieditfield(absoluteGrid, 'numeric');
controlUi.AbsoluteVelYField.Layout.Row = 2; controlUi.AbsoluteVelYField.Layout.Column = 4;
helpers.createRightLabel(absoluteGrid, 'Target Z', 3, 1);
controlUi.TargetZField = uieditfield(absoluteGrid, 'numeric');
controlUi.TargetZField.Layout.Row = 3; controlUi.TargetZField.Layout.Column = 2;
helpers.createRightLabel(absoluteGrid, 'Velocity Z (mm/s)', 3, 3);
controlUi.AbsoluteVelZField = uieditfield(absoluteGrid, 'numeric');
controlUi.AbsoluteVelZField.Layout.Row = 3; controlUi.AbsoluteVelZField.Layout.Column = 4;
helpers.createRightLabel(absoluteGrid, 'Acc X (mm/s^2)', 4, 1);
controlUi.AbsoluteAccXField = uieditfield(absoluteGrid, 'numeric');
controlUi.AbsoluteAccXField.Layout.Row = 4; controlUi.AbsoluteAccXField.Layout.Column = 2;
helpers.createRightLabel(absoluteGrid, 'Acc Y (mm/s^2)', 4, 3);
controlUi.AbsoluteAccYField = uieditfield(absoluteGrid, 'numeric');
controlUi.AbsoluteAccYField.Layout.Row = 4; controlUi.AbsoluteAccYField.Layout.Column = 4;
helpers.createRightLabel(absoluteGrid, 'Acc Z (mm/s^2)', 5, 1);
controlUi.AbsoluteAccZField = uieditfield(absoluteGrid, 'numeric');
controlUi.AbsoluteAccZField.Layout.Row = 5; controlUi.AbsoluteAccZField.Layout.Column = 2;
controlUi.UseCurrentPositionButton = uibutton(absoluteGrid, 'Text', 'Use Current Position', ...
    'ButtonPushedFcn', callbacks.useCurrentPosition);
controlUi.UseCurrentPositionButton.Layout.Row = 6;
controlUi.UseCurrentPositionButton.Layout.Column = [1 2];
controlUi.MoveButton = uibutton(absoluteGrid, 'Text', 'Move', ...
    'ButtonPushedFcn', callbacks.moveAbsolute);
controlUi.MoveButton.Layout.Row = 6;
controlUi.MoveButton.Layout.Column = [3 4];

savedPositionsPanel = uipanel(absoluteGrid, 'Title', 'Saved Positions');
savedPositionsPanel.Layout.Row = 7;
savedPositionsPanel.Layout.Column = [1 4];
savedPositionsGrid = uigridlayout(savedPositionsPanel, [2, 4], ...
    'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
    'RowHeight', {'1x', '1x'}, ...
    'Padding', [4, 2, 4, 2], ...
    'RowSpacing', 4, ...
    'ColumnSpacing', 6);
helpers.enableScrolling(savedPositionsGrid);
for positionIndex = 1:4
    saveButtonName = sprintf('SavePosition%dButton', positionIndex);
    moveButtonName = sprintf('MoveToPosition%dButton', positionIndex);

    controlUi.(saveButtonName) = uibutton(savedPositionsGrid, ...
        'Text', sprintf('Save %d', positionIndex), ...
        'Tooltip', sprintf('Save the current stage position in slot %d', positionIndex), ...
        'ButtonPushedFcn', @(~, ~) callbacks.savePosition(positionIndex));
    controlUi.(saveButtonName).Layout.Row = 1;
    controlUi.(saveButtonName).Layout.Column = positionIndex;

    controlUi.(moveButtonName) = uibutton(savedPositionsGrid, ...
        'Text', sprintf('Go to %d', positionIndex), ...
        'Tooltip', sprintf('Position %d has not been saved yet', positionIndex), ...
        'ButtonPushedFcn', @(~, ~) callbacks.moveToPosition(positionIndex));
    controlUi.(moveButtonName).Layout.Row = 2;
    controlUi.(moveButtonName).Layout.Column = positionIndex;
end

laserStackPanel = uipanel(grid, 'Title', 'Laser & Exposure');
laserStackPanel.Layout.Row = 3;
laserStackPanel.Layout.Column = 5;
laserStackGrid = uigridlayout(laserStackPanel, [1, 1], ...
    'RowHeight', {'1x'}, ...
    'Padding', [8, 8, 8, 8], ...
    'RowSpacing', 0);
helpers.enableScrolling(laserStackGrid);

laserTabs = uitabgroup(laserStackGrid);
exposureTab = uitab(laserTabs, 'Title', 'Exposure');
carbideTab = uitab(laserTabs, 'Title', 'Carbide');

exposureStackGrid = uigridlayout(exposureTab, [1, 3], ...
    'ColumnWidth', {'1x', 6, '1x'}, ...
    'Padding', [8, 8, 8, 8], ...
    'ColumnSpacing', 3);
helpers.enableScrolling(exposureStackGrid);
helpers.createGridSplitter(exposureStackGrid, 1, 2, 'column', 1, 3);

laserPanel = uipanel(exposureStackGrid, 'Title', 'Laser Control');
laserPanel.Layout.Row = 1;
laserPanel.Layout.Column = 1;
laserGrid = uigridlayout(laserPanel, [4, 2], ...
    'ColumnWidth', {'1x', '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', 'fit'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 10);
helpers.enableScrolling(laserGrid);
helpers.createRightLabel(laserGrid, 'Manual Power (%)', 1, 1);
controlUi.LaserPowerField = uieditfield(laserGrid, 'numeric', 'Limits', [0 100]);
controlUi.LaserPowerField.Layout.Row = 1; controlUi.LaserPowerField.Layout.Column = 2;
controlUi.LaserOnButton = uibutton(laserGrid, 'Text', 'Laser ON', ...
    'ButtonPushedFcn', callbacks.laserOn);
controlUi.LaserOnButton.Layout.Row = 2; controlUi.LaserOnButton.Layout.Column = 1;
controlUi.LaserOffButton = uibutton(laserGrid, 'Text', 'Laser OFF', ...
    'ButtonPushedFcn', callbacks.laserOff);
controlUi.LaserOffButton.Layout.Row = 2; controlUi.LaserOffButton.Layout.Column = 2;
helpers.createRightLabel(laserGrid, 'Laser State', 3, 1);
laserStateGrid = uigridlayout(laserGrid, [1, 2], ...
    'ColumnWidth', {22, '1x'}, ...
    'Padding', [0, 0, 0, 0], ...
    'ColumnSpacing', 8);
laserStateGrid.Layout.Row = 3;
laserStateGrid.Layout.Column = 2;
controlUi.LaserStateLamp = uilamp(laserStateGrid, 'Color', [0.85, 0.2, 0.2]);
controlUi.LaserStateLabel = uilabel(laserStateGrid, 'Text', 'Laser Off');
lbl = uilabel(laserGrid, 'Text', 'Stage IO pulse trigger control');
lbl.Layout.Row = 4;
lbl.Layout.Column = [1 2];

carbideGrid = uigridlayout(carbideTab, [11, 4], ...
    'ColumnWidth', {92, '1x', 78, '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x', 'fit'}, ...
    'Padding', [10, 10, 10, 10], ...
    'RowSpacing', 8, ...
    'ColumnSpacing', 8);
helpers.enableScrolling(carbideGrid);
controlUi.CarbideStatusLabel = uilabel(carbideGrid, 'Text', 'Disconnected');
controlUi.CarbideStatusLabel.Layout.Row = 1;
controlUi.CarbideStatusLabel.Layout.Column = [1 4];

helpers.createRightLabel(carbideGrid, 'Power (W)', 2, 1);
controlUi.CarbideActualPowerLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideActualPowerLabel.Layout.Row = 2; controlUi.CarbideActualPowerLabel.Layout.Column = 2;
helpers.createRightLabel(carbideGrid, 'Freq (kHz)', 2, 3);
controlUi.CarbideActualFrequencyLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideActualFrequencyLabel.Layout.Row = 2; controlUi.CarbideActualFrequencyLabel.Layout.Column = 4;

helpers.createRightLabel(carbideGrid, 'Actual PP', 3, 1);
controlUi.CarbideActualPpLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideActualPpLabel.Layout.Row = 3; controlUi.CarbideActualPpLabel.Layout.Column = 2;
helpers.createRightLabel(carbideGrid, 'Pulse (fs)', 3, 3);
controlUi.CarbideActualPulseLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideActualPulseLabel.Layout.Row = 3; controlUi.CarbideActualPulseLabel.Layout.Column = 4;

helpers.createRightLabel(carbideGrid, 'Output', 4, 1);
controlUi.CarbideOutputEnabledLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideOutputEnabledLabel.Layout.Row = 4; controlUi.CarbideOutputEnabledLabel.Layout.Column = 2;
helpers.createRightLabel(carbideGrid, 'Shutter', 4, 3);
controlUi.CarbideShutterStateLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideShutterStateLabel.Layout.Row = 4; controlUi.CarbideShutterStateLabel.Layout.Column = 4;

helpers.createRightLabel(carbideGrid, 'Pulse E (uJ)', 5, 1);
controlUi.CarbidePulseEnergyLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbidePulseEnergyLabel.Layout.Row = 5; controlUi.CarbidePulseEnergyLabel.Layout.Column = 2;

controlUi.CarbideEnableOutputButton = uibutton(carbideGrid, 'Text', 'Open Laser Shutter', ...
    'ButtonPushedFcn', callbacks.enableCarbideOutput);
controlUi.CarbideEnableOutputButton.Layout.Row = 6; controlUi.CarbideEnableOutputButton.Layout.Column = [2 3];
controlUi.CarbideCloseOutputButton = uibutton(carbideGrid, 'Text', 'Close Laser Shutter', ...
    'ButtonPushedFcn', callbacks.closeCarbideOutput);
controlUi.CarbideCloseOutputButton.Layout.Row = 6; controlUi.CarbideCloseOutputButton.Layout.Column = 4;

helpers.createRightLabel(carbideGrid, 'Target PP', 7, 1);
controlUi.CarbidePpDividerField = uieditfield(carbideGrid, 'numeric');
controlUi.CarbidePpDividerField.Layout.Row = 7; controlUi.CarbidePpDividerField.Layout.Column = 2;
controlUi.CarbideApplyPpButton = uibutton(carbideGrid, 'Text', 'Apply PP', ...
    'ButtonPushedFcn', callbacks.applyCarbidePpDivider);
controlUi.CarbideApplyPpButton.Layout.Row = 7; controlUi.CarbideApplyPpButton.Layout.Column = [3 4];

helpers.createRightLabel(carbideGrid, 'Preset', 8, 1);
controlUi.CarbidePresetDropDown = uidropdown(carbideGrid, 'Items', {'(not loaded)'});
controlUi.CarbidePresetDropDown.Layout.Row = 8; controlUi.CarbidePresetDropDown.Layout.Column = [2 3];
controlUi.CarbideApplyPresetButton = uibutton(carbideGrid, 'Text', 'Apply', ...
    'ButtonPushedFcn', callbacks.applyCarbidePreset);
controlUi.CarbideApplyPresetButton.Layout.Row = 8; controlUi.CarbideApplyPresetButton.Layout.Column = 4;

helpers.createRightLabel(carbideGrid, 'Selected', 9, 1);
controlUi.CarbideSelectedPresetLabel = uilabel(carbideGrid, 'Text', '-');
controlUi.CarbideSelectedPresetLabel.Layout.Row = 9; controlUi.CarbideSelectedPresetLabel.Layout.Column = [2 4];
controlUi.CarbideLastErrorLabel = uilabel(carbideGrid, 'Text', '', ...
    'WordWrap', 'on', ...
    'FontColor', [0.72, 0.2, 0.2]);
controlUi.CarbideLastErrorLabel.Layout.Row = 10;
controlUi.CarbideLastErrorLabel.Layout.Column = [1 4];
controlUi.CarbideStandbyButton = uibutton(carbideGrid, 'Text', 'Standby', ...
    'ButtonPushedFcn', callbacks.standbyCarbide);
controlUi.CarbideStandbyButton.Layout.Row = 11;
controlUi.CarbideStandbyButton.Layout.Column = [2 4];
controlUi.CarbideStandbyButton.Tooltip = 'Shut down the Carbide laser into standby';

exposurePanel = uipanel(exposureStackGrid, 'Title', 'Manual Exposure');
exposurePanel.Layout.Row = 1;
exposurePanel.Layout.Column = 3;
exposureGrid = uigridlayout(exposurePanel, [5, 2], ...
    'ColumnWidth', {135, '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', 'fit', 'fit'}, ...
    'Padding', [10, 10, 10, 10], ...
    'RowSpacing', 8);
helpers.enableScrolling(exposureGrid);
helpers.createRightLabel(exposureGrid, 'Exposure (us)', 1, 1);
controlUi.ExposureTimeField = uieditfield(exposureGrid, 'numeric');
controlUi.ExposureTimeField.Layout.Row = 1; controlUi.ExposureTimeField.Layout.Column = 2;
helpers.createRightLabel(exposureGrid, 'Repeat', 2, 1);
controlUi.ExposureRepeatField = uieditfield(exposureGrid, 'numeric');
controlUi.ExposureRepeatField.Layout.Row = 2; controlUi.ExposureRepeatField.Layout.Column = 2;
helpers.createRightLabel(exposureGrid, 'Interval (s)', 3, 1);
controlUi.ExposureIntervalField = uieditfield(exposureGrid, 'numeric');
controlUi.ExposureIntervalField.Layout.Row = 3; controlUi.ExposureIntervalField.Layout.Column = 2;
helpers.createRightLabel(exposureGrid, 'Exposure Power (%)', 4, 1);
controlUi.PreviewPowerField = uieditfield(exposureGrid, 'numeric', 'Limits', [0 100]);
controlUi.PreviewPowerField.Layout.Row = 4; controlUi.PreviewPowerField.Layout.Column = 2;
controlUi.FireExposureButton = uibutton(exposureGrid, 'Text', 'Fire Exposure', ...
    'ButtonPushedFcn', callbacks.fireExposure);
controlUi.FireExposureButton.Layout.Row = 5;
controlUi.FireExposureButton.Layout.Column = [1 2];
end
