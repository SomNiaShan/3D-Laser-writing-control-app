function trajectoryUi = lw_build_trajectory_tab(tab, callbacks, helpers)
%LW_BUILD_TRAJECTORY_TAB Build the plan source, placement, and preview UI.

trajectoryUi = struct();

grid = uigridlayout(tab, [3, 3], ...
    'ColumnWidth', {'1.02x', 6, '1.18x'}, ...
    'RowHeight', {'1x', 6, '1x'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 3, ...
    'ColumnSpacing', 3);
helpers.createGridSplitter(grid, [1 3], 2, 'column', 1, 3);
helpers.createGridSplitter(grid, 2, 1, 'row', 1, 3);

sourcePanel = uipanel(grid, 'Title', 'Input Source');
sourcePanel.Layout.Row = 1;
sourcePanel.Layout.Column = 1;
sourceGrid = uigridlayout(sourcePanel, [9, 2], ...
    'ColumnWidth', {130, '1x'}, ...
    'RowHeight', {90, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(sourceGrid);
trajectoryUi.SourceGrid = sourceGrid;

trajectoryUi.SourceModeGroup = uibuttongroup(sourceGrid, 'Title', 'Mode', ...
    'SelectionChangedFcn', callbacks.sourceModeChanged);
trajectoryUi.SourceModeGroup.Layout.Row = 1;
trajectoryUi.SourceModeGroup.Layout.Column = [1 2];
trajectoryUi.ImportedPointsRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Imported Points', 'Value', true, 'Position', [14, 36, 120, 22]);
trajectoryUi.MarkTextRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Mark Text', 'Position', [160, 36, 100, 22]);
trajectoryUi.FrameRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'Frame', 'Position', [280, 36, 80, 22]);
trajectoryUi.GCodeRadio = uiradiobutton(trajectoryUi.SourceModeGroup, ...
    'Text', 'G-code (Phase 2)', 'Enable', 'off', 'Position', [14, 10, 140, 22]);

trajectoryUi.InputFileLabel = helpers.createRightLabel(sourceGrid, 'Input File', 2, 1);
trajectoryUi.InputFileField = uieditfield(sourceGrid, 'text');
trajectoryUi.InputFileField.Layout.Row = 2;
trajectoryUi.InputFileField.Layout.Column = 2;

trajectoryUi.BrowseInputFileButton = uibutton(sourceGrid, 'Text', 'Browse', ...
    'ButtonPushedFcn', callbacks.browseInputFile);
trajectoryUi.BrowseInputFileButton.Layout.Row = 3;
trajectoryUi.BrowseInputFileButton.Layout.Column = 2;

trajectoryUi.ColumnXLabel = helpers.createRightLabel(sourceGrid, 'Column X', 4, 1);
trajectoryUi.ColumnXField = uieditfield(sourceGrid, 'text');
trajectoryUi.ColumnXField.Layout.Row = 4;
trajectoryUi.ColumnXField.Layout.Column = 2;
trajectoryUi.ColumnYLabel = helpers.createRightLabel(sourceGrid, 'Column Y', 5, 1);
trajectoryUi.ColumnYField = uieditfield(sourceGrid, 'text');
trajectoryUi.ColumnYField.Layout.Row = 5;
trajectoryUi.ColumnYField.Layout.Column = 2;
trajectoryUi.ColumnZLabel = helpers.createRightLabel(sourceGrid, 'Column Z', 6, 1);
trajectoryUi.ColumnZField = uieditfield(sourceGrid, 'text');
trajectoryUi.ColumnZField.Layout.Row = 6;
trajectoryUi.ColumnZField.Layout.Column = 2;
trajectoryUi.ColumnPLabel = helpers.createRightLabel(sourceGrid, 'Column P', 7, 1);
trajectoryUi.ColumnPField = uieditfield(sourceGrid, 'text');
trajectoryUi.ColumnPField.Layout.Row = 7;
trajectoryUi.ColumnPField.Layout.Column = 2;
trajectoryUi.PlanPowerLabel = helpers.createRightLabel(sourceGrid, 'XYZ-only Power (%)', 8, 1);
trajectoryUi.PlanPowerField = uieditfield(sourceGrid, 'numeric', ...
    'Limits', [0 100], ...
    'ValueChangedFcn', callbacks.planPowerChanged);
trajectoryUi.PlanPowerField.Layout.Row = 8;
trajectoryUi.PlanPowerField.Layout.Column = 2;
trajectoryUi.PlanPowerField.Tooltip = 'Used only when an imported numeric points file contains XYZ columns without a power column';

trajectoryUi.ImportGenerateButton = uibutton(sourceGrid, 'Text', 'Import Plan', ...
    'ButtonPushedFcn', callbacks.importOrGenerateTrajectory);
trajectoryUi.ImportGenerateButton.Layout.Row = 9;
trajectoryUi.ImportGenerateButton.Layout.Column = [1 2];

placementPanel = uipanel(grid, 'Title', 'Placement');
placementPanel.Layout.Row = 3;
placementPanel.Layout.Column = 1;
placementGrid = uigridlayout(placementPanel, [7, 4], ...
    'ColumnWidth', {70, '1x', 70, '1x'}, ...
    'RowHeight', {'fit', 'fit', 'fit', 'fit', 'fit', '1x', 'fit'}, ...
    'Padding', [12, 12, 12, 12], ...
    'RowSpacing', 8);
helpers.enableScrolling(placementGrid);

helpers.createRightLabel(placementGrid, 'Start X', 1, 1);
trajectoryUi.StartXField = uieditfield(placementGrid, 'numeric');
trajectoryUi.StartXField.Layout.Row = 1; trajectoryUi.StartXField.Layout.Column = 2;
helpers.createRightLabel(placementGrid, 'Mx', 1, 3);
trajectoryUi.MagnificationXField = uieditfield(placementGrid, 'numeric');
trajectoryUi.MagnificationXField.Layout.Row = 1; trajectoryUi.MagnificationXField.Layout.Column = 4;
helpers.createRightLabel(placementGrid, 'Start Y', 2, 1);
trajectoryUi.StartYField = uieditfield(placementGrid, 'numeric');
trajectoryUi.StartYField.Layout.Row = 2; trajectoryUi.StartYField.Layout.Column = 2;
helpers.createRightLabel(placementGrid, 'My', 2, 3);
trajectoryUi.MagnificationYField = uieditfield(placementGrid, 'numeric');
trajectoryUi.MagnificationYField.Layout.Row = 2; trajectoryUi.MagnificationYField.Layout.Column = 4;
helpers.createRightLabel(placementGrid, 'Start Z', 3, 1);
trajectoryUi.StartZField = uieditfield(placementGrid, 'numeric');
trajectoryUi.StartZField.Layout.Row = 3; trajectoryUi.StartZField.Layout.Column = 2;
helpers.createRightLabel(placementGrid, 'Mz', 3, 3);
trajectoryUi.MagnificationZField = uieditfield(placementGrid, 'numeric');
trajectoryUi.MagnificationZField.Layout.Row = 3; trajectoryUi.MagnificationZField.Layout.Column = 4;
trajectoryUi.UseCurrentOriginButton = uibutton(placementGrid, 'Text', 'Use Current Position', ...
    'ButtonPushedFcn', callbacks.useCurrentPosition);
trajectoryUi.UseCurrentOriginButton.Layout.Row = 4;
trajectoryUi.UseCurrentOriginButton.Layout.Column = [1 4];
trajectoryUi.TransformHintLabel = uilabel(placementGrid, ...
    'Text', 'Set Start XYZ on the left and Mx / My / Mz on the right.');
trajectoryUi.TransformHintLabel.Layout.Row = 5;
trajectoryUi.TransformHintLabel.Layout.Column = [1 4];
trajectoryUi.EnableZCompensationCheckBox = uicheckbox(placementGrid, 'Text', 'Enable Leveling');
trajectoryUi.EnableZCompensationCheckBox.Layout.Row = 7;
trajectoryUi.EnableZCompensationCheckBox.Layout.Column = [1 4];

previewPanel = uipanel(grid, 'Title', 'Preview');
previewPanel.Layout.Row = [1 3];
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
trajectoryUi.PreviewNoteLabel = uilabel(previewGrid, 'Text', 'Plan: none loaded');
trajectoryUi.PreviewNoteLabel.Layout.Row = 2;
trajectoryUi.PreviewNoteLabel.Layout.Column = 1;
end
