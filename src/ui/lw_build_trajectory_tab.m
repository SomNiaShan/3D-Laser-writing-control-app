function trajectoryUi = lw_build_trajectory_tab(tab, callbacks, helpers, options)
%LW_BUILD_TRAJECTORY_TAB Build every plan source, parameter, and preview UI.

trajectoryUi = struct();

grid = uigridlayout(tab, [1, 3], ...
    'ColumnWidth', {'0.95x', 6, '1.25x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'ColumnSpacing', 3);
helpers.createGridSplitter(grid, 1, 2, 'column', 1, 3);

builderPanel = uipanel(grid, 'Title', 'Plan Builder');
builderPanel.Layout.Row = 1;
builderPanel.Layout.Column = 1;
builderGrid = uigridlayout(builderPanel, [16, 4], ...
    'ColumnWidth', {112, '1x', 112, '1x'}, ...
    'RowHeight', {82, 'fit', 'fit', 0, 0, 'fit', 'fit', 'fit', ...
        'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 7);
helpers.enableScrolling(builderGrid);
trajectoryUi.SourceGrid = builderGrid;
trajectoryUi.PlanBuilderGrid = builderGrid;

trajectoryUi.SourceModeGroup = uibuttongroup(builderGrid, 'Title', 'Plan Source', ...
    'SelectionChangedFcn', callbacks.sourceModeChanged);
trajectoryUi.SourceModeGroup.Layout.Row = 1;
trajectoryUi.SourceModeGroup.Layout.Column = [1 4];
trajectoryUi.ImportedPointsRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Imported Points', 'Value', true, 'Position', [14, 34, 120, 22]);
trajectoryUi.MarkTextRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Mark Text', 'Position', [150, 34, 100, 22]);
trajectoryUi.FrameRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Frame', 'Position', [265, 34, 80, 22]);
trajectoryUi.ZSweepRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Z Sweep', 'Position', [360, 34, 90, 22]);
trajectoryUi.GCodeRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'G-code (Phase 2)', 'Enable', 'off', 'Position', [14, 8, 140, 22]);

trajectoryUi.InputFileLabel = helpers.createRightLabel(builderGrid, 'Input File', 2, 1);
trajectoryUi.InputFileField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.InputFileField.Layout.Row = 2;
trajectoryUi.InputFileField.Layout.Column = [2 4];

trajectoryUi.BrowseInputFileButton = uibutton(builderGrid, 'Text', 'Browse', ...
    'ButtonPushedFcn', callbacks.browseInputFile);
trajectoryUi.BrowseInputFileButton.Layout.Row = 3;
trajectoryUi.BrowseInputFileButton.Layout.Column = [2 4];

trajectoryUi.ColumnXLabel = helpers.createRightLabel(builderGrid, 'Column X', 4, 1);
trajectoryUi.ColumnXField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.ColumnXField.Layout.Row = 4;
trajectoryUi.ColumnXField.Layout.Column = 2;
trajectoryUi.ColumnYLabel = helpers.createRightLabel(builderGrid, 'Column Y', 4, 3);
trajectoryUi.ColumnYField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.ColumnYField.Layout.Row = 4;
trajectoryUi.ColumnYField.Layout.Column = 4;
trajectoryUi.ColumnZLabel = helpers.createRightLabel(builderGrid, 'Column Z', 5, 1);
trajectoryUi.ColumnZField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.ColumnZField.Layout.Row = 5;
trajectoryUi.ColumnZField.Layout.Column = 2;
trajectoryUi.ColumnPLabel = helpers.createRightLabel(builderGrid, 'Column P', 5, 3);
trajectoryUi.ColumnPField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.ColumnPField.Layout.Row = 5;
trajectoryUi.ColumnPField.Layout.Column = 4;
trajectoryUi.PlanPowerLabel = helpers.createRightLabel(builderGrid, 'Power (%)', 6, 1);
trajectoryUi.UseFixedPowerCheckBox = uicheckbox(builderGrid, ...
    'Text', 'Use Fixed Power (%)', ...
    'ValueChangedFcn', callbacks.fixedPowerOverrideChanged);
trajectoryUi.UseFixedPowerCheckBox.Layout.Row = 6;
trajectoryUi.UseFixedPowerCheckBox.Layout.Column = [1 2];
trajectoryUi.UseFixedPowerCheckBox.Tooltip = ...
    'When selected, every imported operation uses the fixed power value and file power is ignored';
trajectoryUi.PlanPowerField = uieditfield(builderGrid, 'numeric', ...
    'Limits', [0 100], ...
    'ValueChangedFcn', callbacks.planPowerChanged);
trajectoryUi.PlanPowerField.Layout.Row = 6;
trajectoryUi.PlanPowerField.Layout.Column = 4;
trajectoryUi.PlanPowerField.Tooltip = ...
    'Fixed execution power used for every imported operation when enabled';

trajectoryUi.ImportGenerateButton = uibutton(builderGrid, 'Text', 'Import Plan', ...
    'ButtonPushedFcn', callbacks.importOrGenerateTrajectory);
trajectoryUi.ImportGenerateButton.Layout.Row = 7;
trajectoryUi.ImportGenerateButton.Layout.Column = [1 4];

trajectoryUi.PlacementSectionLabel = uilabel(builderGrid, ...
    'Text', 'Placement and point defaults', 'FontWeight', 'bold');
trajectoryUi.PlacementSectionLabel.Layout.Row = 8;
trajectoryUi.PlacementSectionLabel.Layout.Column = [1 4];
trajectoryUi.StartXLabel = helpers.createRightLabel(builderGrid, 'Start X', 9, 1);
trajectoryUi.StartXField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.StartXField.Layout.Row = 9; trajectoryUi.StartXField.Layout.Column = 2;
trajectoryUi.MagnificationXLabel = helpers.createRightLabel(builderGrid, 'Mx', 9, 3);
trajectoryUi.MagnificationXField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.MagnificationXField.Layout.Row = 9; trajectoryUi.MagnificationXField.Layout.Column = 4;
trajectoryUi.StartYLabel = helpers.createRightLabel(builderGrid, 'Start Y', 10, 1);
trajectoryUi.StartYField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.StartYField.Layout.Row = 10; trajectoryUi.StartYField.Layout.Column = 2;
trajectoryUi.MagnificationYLabel = helpers.createRightLabel(builderGrid, 'My', 10, 3);
trajectoryUi.MagnificationYField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.MagnificationYField.Layout.Row = 10; trajectoryUi.MagnificationYField.Layout.Column = 4;
trajectoryUi.StartZLabel = helpers.createRightLabel(builderGrid, 'Start Z', 11, 1);
trajectoryUi.StartZField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.StartZField.Layout.Row = 11; trajectoryUi.StartZField.Layout.Column = 2;
trajectoryUi.MagnificationZLabel = helpers.createRightLabel(builderGrid, 'Mz', 11, 3);
trajectoryUi.MagnificationZField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.MagnificationZField.Layout.Row = 11; trajectoryUi.MagnificationZField.Layout.Column = 4;
trajectoryUi.UseCurrentOriginButton = uibutton(builderGrid, 'Text', 'Use Current Position', ...
    'ButtonPushedFcn', callbacks.useCurrentPosition);
trajectoryUi.UseCurrentOriginButton.Layout.Row = 12;
trajectoryUi.UseCurrentOriginButton.Layout.Column = [1 4];
trajectoryUi.TransformHintLabel = uilabel(builderGrid, ...
    'Text', 'Set Start XYZ and Mx / My / Mz before preparing the plan.');
trajectoryUi.TransformHintLabel.Layout.Row = 13;
trajectoryUi.TransformHintLabel.Layout.Column = [1 4];
trajectoryUi.EnableZCompensationCheckBox = uicheckbox(builderGrid, ...
    'Text', 'Enable Leveling', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.EnableZCompensationCheckBox.Layout.Row = 14;
trajectoryUi.EnableZCompensationCheckBox.Layout.Column = [1 4];
trajectoryUi.PointExposureLabel = helpers.createRightLabel(builderGrid, 'Default Dwell (us)', 15, 1);
trajectoryUi.PointExposureField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.PointExposureField.Layout.Row = 15;
trajectoryUi.PointExposureField.Layout.Column = 2;
trajectoryUi.PointExposureField.Tooltip = ...
    'Fallback dwell frozen into point plans that do not provide dwell_s.';
trajectoryUi.PointPauseLabel = helpers.createRightLabel(builderGrid, 'Default Settle (s)', 15, 3);
trajectoryUi.PointPauseField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.planInputChanged);
trajectoryUi.PointPauseField.Layout.Row = 15;
trajectoryUi.PointPauseField.Layout.Column = 4;
trajectoryUi.PointPauseField.Tooltip = ...
    'Fallback pre-write settling time frozen into point plans without pause_s.';

trajectoryUi.ZSweepPowerLabel = helpers.createRightLabel(builderGrid, 'Sweep Power (%)', 2, 1);
trajectoryUi.ZSweepPowerField = uieditfield(builderGrid, 'numeric', ...
    'Limits', [0 100], 'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepPowerField.Layout.Row = 2; trajectoryUi.ZSweepPowerField.Layout.Column = 2;
trajectoryUi.ZSweepDirectionLabel = helpers.createRightLabel(builderGrid, 'Exposure Dir', 2, 3);
trajectoryUi.ZSweepDirectionDropDown = uidropdown(builderGrid, ...
    'Items', {'Back -> Front', 'Front -> Back', 'Both Directions'}, ...
    'Value', 'Back -> Front', 'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepDirectionDropDown.Layout.Row = 2;
trajectoryUi.ZSweepDirectionDropDown.Layout.Column = 4;
trajectoryUi.ZSweepXLabel = helpers.createRightLabel(builderGrid, 'Sweep X', 3, 1);
trajectoryUi.ZSweepXField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepXField.Layout.Row = 3; trajectoryUi.ZSweepXField.Layout.Column = 2;
trajectoryUi.ZSweepYLabel = helpers.createRightLabel(builderGrid, 'Sweep Y', 3, 3);
trajectoryUi.ZSweepYField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepYField.Layout.Row = 3; trajectoryUi.ZSweepYField.Layout.Column = 4;
trajectoryUi.ZSweepBackLabel = helpers.createRightLabel(builderGrid, 'Z Back', 4, 1);
trajectoryUi.ZSweepBackField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepBackField.Layout.Row = 4; trajectoryUi.ZSweepBackField.Layout.Column = 2;
trajectoryUi.ZSweepFrontLabel = helpers.createRightLabel(builderGrid, 'Z Front', 4, 3);
trajectoryUi.ZSweepFrontField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepFrontField.Layout.Row = 4; trajectoryUi.ZSweepFrontField.Layout.Column = 4;
trajectoryUi.ZSweepSpeedLabel = helpers.createRightLabel(builderGrid, 'Sweep Speed (mm/s)', 5, 1);
trajectoryUi.ZSweepSpeedField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepSpeedField.Layout.Row = 5; trajectoryUi.ZSweepSpeedField.Layout.Column = 2;
trajectoryUi.ZSweepReturnSpeedLabel = helpers.createRightLabel(builderGrid, 'Return Speed (mm/s)', 5, 3);
trajectoryUi.ZSweepReturnSpeedField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepReturnSpeedField.Layout.Row = 5;
trajectoryUi.ZSweepReturnSpeedField.Layout.Column = 4;
trajectoryUi.ZSweepRepeatLabel = helpers.createRightLabel(builderGrid, 'Repeat Count', 6, 1);
trajectoryUi.ZSweepRepeatField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepPreviewChanged);
trajectoryUi.ZSweepRepeatField.Layout.Row = 6; trajectoryUi.ZSweepRepeatField.Layout.Column = 2;
trajectoryUi.ZSweepUseCurrentButton = uibutton(builderGrid, 'Text', 'Use Current Position', ...
    'ButtonPushedFcn', callbacks.useCurrentZSweepPosition);
trajectoryUi.ZSweepUseCurrentButton.Layout.Row = 6;
trajectoryUi.ZSweepUseCurrentButton.Layout.Column = [3 4];
trajectoryUi.ZSweepMatrixCheckBox = uicheckbox(builderGrid, ...
    'Text', 'Parameter Matrix', 'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepMatrixCheckBox.Layout.Row = 7;
trajectoryUi.ZSweepMatrixCheckBox.Layout.Column = [1 2];
trajectoryUi.ZSweepMatrixHintLabel = uilabel(builderGrid, ...
    'Text', 'Choose two parameters for X/Y grid axes');
trajectoryUi.ZSweepMatrixHintLabel.Layout.Row = 7;
trajectoryUi.ZSweepMatrixHintLabel.Layout.Column = [3 4];
trajectoryUi.ZSweepMatrixXParamLabel = helpers.createRightLabel(builderGrid, 'X Param', 8, 1);
trajectoryUi.ZSweepMatrixXParamDropDown = uidropdown(builderGrid, ...
    'Items', options.zSweepMatrixParameterItems, 'Value', 'Power (%)', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepMatrixXParamDropDown.Layout.Row = 8;
trajectoryUi.ZSweepMatrixXParamDropDown.Layout.Column = 2;
trajectoryUi.ZSweepMatrixYParamLabel = helpers.createRightLabel(builderGrid, 'Y Param', 8, 3);
trajectoryUi.ZSweepMatrixYParamDropDown = uidropdown(builderGrid, ...
    'Items', options.zSweepMatrixParameterItems, 'Value', 'Sweep Speed (mm/s)', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepMatrixYParamDropDown.Layout.Row = 8;
trajectoryUi.ZSweepMatrixYParamDropDown.Layout.Column = 4;
trajectoryUi.ZSweepMatrixXValuesLabel = helpers.createRightLabel(builderGrid, 'X Values', 9, 1);
trajectoryUi.ZSweepMatrixXValuesField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepMatrixXValuesField.Layout.Row = 9;
trajectoryUi.ZSweepMatrixXValuesField.Layout.Column = 2;
trajectoryUi.ZSweepMatrixYValuesLabel = helpers.createRightLabel(builderGrid, 'Y Values', 9, 3);
trajectoryUi.ZSweepMatrixYValuesField = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepMatrixYValuesField.Layout.Row = 9;
trajectoryUi.ZSweepMatrixYValuesField.Layout.Column = 4;
trajectoryUi.ZSweepPitchXLabel = helpers.createRightLabel(builderGrid, 'Pitch X (mm)', 10, 1);
trajectoryUi.ZSweepPitchXField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepPitchXField.Layout.Row = 10; trajectoryUi.ZSweepPitchXField.Layout.Column = 2;
trajectoryUi.ZSweepPitchYLabel = helpers.createRightLabel(builderGrid, 'Pitch Y (mm)', 10, 3);
trajectoryUi.ZSweepPitchYField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepPitchYField.Layout.Row = 10; trajectoryUi.ZSweepPitchYField.Layout.Column = 4;
trajectoryUi.ZSweepBlockCheckBox = uicheckbox(builderGrid, ...
    'Text', 'Blocks', 'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockCheckBox.Layout.Row = 11;
trajectoryUi.ZSweepBlockCheckBox.Layout.Column = [1 2];
trajectoryUi.ZSweepBlockHintLabel = uilabel(builderGrid, ...
    'Text', 'Outer block matrix; each block contains the matrix above');
trajectoryUi.ZSweepBlockHintLabel.Layout.Row = 11;
trajectoryUi.ZSweepBlockHintLabel.Layout.Column = [3 4];
trajectoryUi.ZSweepBlockParam1Label = helpers.createRightLabel(builderGrid, 'Block X Param', 12, 1);
trajectoryUi.ZSweepBlockParam1DropDown = uidropdown(builderGrid, ...
    'Items', options.zSweepMatrixBlockParameterItems, 'Value', 'None', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockParam1DropDown.Layout.Row = 12;
trajectoryUi.ZSweepBlockParam1DropDown.Layout.Column = 2;
trajectoryUi.ZSweepBlockValues1Label = helpers.createRightLabel(builderGrid, 'Block X Values', 12, 3);
trajectoryUi.ZSweepBlockValues1Field = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockValues1Field.Layout.Row = 12;
trajectoryUi.ZSweepBlockValues1Field.Layout.Column = 4;
trajectoryUi.ZSweepBlockParam2Label = helpers.createRightLabel(builderGrid, 'Block Y Param', 13, 1);
trajectoryUi.ZSweepBlockParam2DropDown = uidropdown(builderGrid, ...
    'Items', options.zSweepMatrixBlockParameterItems, 'Value', 'None', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockParam2DropDown.Layout.Row = 13;
trajectoryUi.ZSweepBlockParam2DropDown.Layout.Column = 2;
trajectoryUi.ZSweepBlockValues2Label = helpers.createRightLabel(builderGrid, 'Block Y Values', 13, 3);
trajectoryUi.ZSweepBlockValues2Field = uieditfield(builderGrid, 'text', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockValues2Field.Layout.Row = 13;
trajectoryUi.ZSweepBlockValues2Field.Layout.Column = 4;
trajectoryUi.ZSweepBlockPitchXLabel = helpers.createRightLabel(builderGrid, 'Block Pitch X', 14, 1);
trajectoryUi.ZSweepBlockPitchXField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockPitchXField.Layout.Row = 14;
trajectoryUi.ZSweepBlockPitchXField.Layout.Column = 2;
trajectoryUi.ZSweepBlockPitchYLabel = helpers.createRightLabel(builderGrid, 'Block Pitch Y', 14, 3);
trajectoryUi.ZSweepBlockPitchYField = uieditfield(builderGrid, 'numeric', ...
    'ValueChangedFcn', callbacks.zSweepMatrixChanged);
trajectoryUi.ZSweepBlockPitchYField.Layout.Row = 14;
trajectoryUi.ZSweepBlockPitchYField.Layout.Column = 4;

trajectoryUi.PlanBuilderHintLabel = uilabel(builderGrid, ...
    'Text', 'Prepare the plan here; Run reads the frozen plan without a mode selection.', ...
    'WordWrap', 'on');
trajectoryUi.PlanBuilderHintLabel.Layout.Row = 16;
trajectoryUi.PlanBuilderHintLabel.Layout.Column = [1 4];

previewPanel = uipanel(grid, 'Title', 'Plan Preview');
previewPanel.Layout.Row = 1;
previewPanel.Layout.Column = 3;
previewGrid = uigridlayout(previewPanel, [2, 1], ...
    'RowHeight', {'1x', 26}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
trajectoryUi.TrajectoryAxes = uiaxes(previewGrid);
trajectoryUi.TrajectoryAxes.Layout.Row = 1;
trajectoryUi.TrajectoryAxes.Layout.Column = 1;
title(trajectoryUi.TrajectoryAxes, 'XYZ Preview');
xlabel(trajectoryUi.TrajectoryAxes, 'X (mm)');
ylabel(trajectoryUi.TrajectoryAxes, 'Y (mm)');
zlabel(trajectoryUi.TrajectoryAxes, 'Z (mm)');
trajectoryUi.TrajectoryAxes.XGrid = 'on';
trajectoryUi.TrajectoryAxes.YGrid = 'on';
trajectoryUi.TrajectoryAxes.ZGrid = 'on';
trajectoryUi.TrajectoryAxes.DataAspectRatio = [1, 1, 1];
trajectoryUi.TrajectoryAxes.DataAspectRatioMode = 'manual';
trajectoryUi.PreviewNoteLabel = uilabel(previewGrid, 'Text', 'Plan: none prepared');
trajectoryUi.PreviewNoteLabel.Layout.Row = 2;
trajectoryUi.PreviewNoteLabel.Layout.Column = 1;
end
