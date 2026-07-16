classdef TrajectoryController < handle
    %TRAJECTORYCONTROLLER Own plan sources, transforms, leveling, and previews.

    properties (SetAccess = private)
        Model
        Ports
    end

    methods
        function obj = TrajectoryController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("TrajectoryController", ports, [ ...
                "apply3DPreviewLimits", "buildZSweepMatrix", "clearPreviewColorbar", ...
                "displayYToStage", "logMessage", "runUiAction", "selectedRunMode", ...
                "stageLaser", "stageYToDisplay", "syncAll", "validateTargetForUi"]);
        end

        function initializeSourceModeMemory(obj)
            obj.Model.SourceModeMemory = struct( ...
                'importedPoints', obj.sourceModeFields('', '', '', '', '', 10), ...
                'markText', obj.sourceModeFields('', 'TEXT', '0.01', '', '', 10), ...
                'frame', obj.sourceModeFields('Outer ring of an MxN point grid', '10', '10', '0.01', '0.01', 10), ...
                'gcode', obj.sourceModeFields('', '', '', '', '', 10));
            obj.Model.CurrentSourceMode = obj.selectedSourceMode();
            obj.restoreSourceModeFields(obj.Model.CurrentSourceMode);
        end

        function values = sourceModeFields(~, inputFile, columnX, columnY, columnZ, columnP, planPower)
            values = struct( ...
                'inputFile', string(inputFile), ...
                'columnX', string(columnX), ...
                'columnY', string(columnY), ...
                'columnZ', string(columnZ), ...
                'columnP', string(columnP), ...
                'planPower', double(planPower));
        end

        function saveSourceModeFields(obj, mode)
            obj.Model.SourceModeMemory.(obj.sourceModeStorageKey(mode)) = obj.sourceModeFields( ...
                obj.Model.Ui.InputFileField.Value, ...
                obj.Model.Ui.ColumnXField.Value, ...
                obj.Model.Ui.ColumnYField.Value, ...
                obj.Model.Ui.ColumnZField.Value, ...
                obj.Model.Ui.ColumnPField.Value, ...
                obj.Model.Ui.PlanPowerField.Value);
        end

        function restoreSourceModeFields(obj, mode)
            values = obj.Model.SourceModeMemory.(obj.sourceModeStorageKey(mode));
            obj.Model.Ui.InputFileField.Value = values.inputFile;
            obj.Model.Ui.ColumnXField.Value = values.columnX;
            obj.Model.Ui.ColumnYField.Value = values.columnY;
            obj.Model.Ui.ColumnZField.Value = values.columnZ;
            obj.Model.Ui.ColumnPField.Value = values.columnP;
            obj.Model.Ui.PlanPowerField.Value = values.planPower;
        end

        function key = sourceModeStorageKey(~, mode)
            switch string(mode)
                case "Imported Points"
                    key = 'importedPoints';
                case "Mark Text"
                    key = 'markText';
                case "Frame"
                    key = 'frame';
                otherwise
                    key = 'gcode';
            end
        end

        function onBrowseInputFile(obj, ~, ~)
            [fileName, pathName] = obj.Model.Services.dialog.openFile( ...
                {'*.csv;*.txt;*.dat', 'Numeric files'; '*.*', 'All files'}, ...
                'Select input file');
            if isequal(fileName, 0)
                return;
            end
            obj.Model.Ui.InputFileField.Value = fullfile(pathName, fileName);
            obj.Ports.logMessage(sprintf('Selected input file: %s', obj.Model.Ui.InputFileField.Value));
        end

        function onSourceModeChanged(obj, ~, ~)
            obj.saveSourceModeFields(obj.Model.CurrentSourceMode);
            obj.Model.CurrentSourceMode = obj.selectedSourceMode();
            obj.restoreSourceModeFields(obj.Model.CurrentSourceMode);
            obj.Ports.syncAll();
        end

        function onRunModeChanged(obj, ~, ~)
            obj.Ports.syncAll();
        end

        function onPlanPowerChanged(obj, ~, ~)
            if isempty(obj.Model.Trajectory) || ~obj.currentSourceMatchesLoadedTrajectory()
                obj.Ports.syncAll();
                return;
            end
            if trajectoryPowerSource(obj.Model.Trajectory) == "file"
                obj.Ports.syncAll();
                return;
            end

            obj.Model.TrajectoryInputsDirty = true;
            obj.Model.RunCurrentText = "Plan power changed - regenerate or re-import";
            obj.Ports.logMessage('Plan power input changed; regenerate or re-import the plan before running.');
            obj.Ports.syncAll();
        end

        function onZSweepPreviewChanged(obj, ~, ~)
            obj.Ports.syncAll();
        end

        function onZSweepMatrixChanged(obj, ~, ~)
            obj.Ports.syncAll();
        end

        function onImportOrGenerateTrajectory(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.importTrajectoryImpl(), 'Failed while preparing plan');
        end

        function importTrajectoryImpl(obj)
            obj.Model.Trajectory = obj.buildTrajectoryFromUi();
            obj.Model.State.trajectory = obj.Model.Trajectory;
            obj.Model.TrajectoryInputsDirty = false;
            obj.Model.RunProgressText = sprintf('0 / %d', numel(obj.Model.Trajectory.x));
            obj.Model.RunCurrentText = "Plan loaded";
            obj.Ports.logMessage(sprintf('Plan ready: %d points, source = %s.', ...
                numel(obj.Model.Trajectory.x), char(obj.Model.Trajectory.sourceType)));
        end

        function out = buildTrajectoryFromUi(obj)
            sourceMode = obj.selectedSourceMode();
            switch sourceMode
                case "Imported Points"
                    filename = strtrim(string(obj.Model.Ui.InputFileField.Value));
                    if filename == ""
                        error('Please select an input file first.');
                    end

                    out = lw_import_points_table(filename, obj.Model.Ui.PlanPowerField.Value);

                case "Mark Text"
                    markText = string(obj.Model.Ui.ColumnXField.Value);
                    pitchMm = positiveScalar(str2double(obj.Model.Ui.ColumnYField.Value), 'Mark pitch');
                    out = lw_generate_mark_trajectory(markText, pitchMm, obj.Model.Ui.PlanPowerField.Value);

                case "Frame"
                    countX = positiveInteger(str2double(obj.Model.Ui.ColumnXField.Value), 'Frame points X');
                    countY = positiveInteger(str2double(obj.Model.Ui.ColumnYField.Value), 'Frame points Y');
                    pitchX = positiveScalar(str2double(obj.Model.Ui.ColumnZField.Value), 'Frame pitch X');
                    pitchY = positiveScalar(str2double(obj.Model.Ui.ColumnPField.Value), 'Frame pitch Y');
                    out = lw_generate_frame_trajectory(countX, countY, pitchX, pitchY, obj.Model.Ui.PlanPowerField.Value);

                otherwise
                    error('G-code import is planned next, but not wired yet.');
            end

            originDisplay = obj.readOriginDisplay();
            magnification = obj.readMagnification();
            out = lw_apply_transform(out, originDisplay, magnification);
            out = obj.trajectoryDisplayYToStage(out);
            if obj.Model.Ui.EnableZCompensationCheckBox.Value
                originStage = struct( ...
                    'x', originDisplay.x, ...
                    'y', obj.Ports.displayYToStage(originDisplay.y), ...
                    'z', originDisplay.z);
                out = lw_apply_z_compensation(out, obj.Model.State.marks, originStage);
            end
        end

        function out = trajectoryDisplayYToStage(obj, out)
            out.y = obj.Ports.displayYToStage(out.y);
            if ~isfield(out, 'cutPlan') || ~istable(out.cutPlan)
                return;
            end

            yFields = {'y', 'y2', 'leadY', 'exitY'};
            for i = 1:numel(yFields)
                fieldName = yFields{i};
                if ismember(fieldName, out.cutPlan.Properties.VariableNames)
                    out.cutPlan.(fieldName) = obj.Ports.displayYToStage(out.cutPlan.(fieldName));
                end
            end
        end

        function onCaptureMark(obj, markName)
            displayName = char(markDisplayName(markName));
            obj.Ports.runUiAction(@() obj.captureMarkImpl(markName), sprintf('Failed to capture %s', displayName));
        end

        function captureMarkImpl(obj, markName)
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
            obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
            obj.Model.State.marks.(markName) = [obj.Model.State.currentPosition.x, obj.Model.State.currentPosition.y, obj.Model.State.currentPosition.z];
            obj.Ports.logMessage(sprintf('%s captured at X %.3f, Y %.3f, Z %.3f mm.', ...
                markDisplayName(markName), obj.Model.State.currentPosition.x, ...
                obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), obj.Model.State.currentPosition.z));
        end

        function syncLevelingUi(obj)
            obj.syncReferenceStatus(obj.Model.Ui.PointAStatusLabel, 'Point A', obj.Model.State.marks.mark0);
            obj.syncReferenceStatus(obj.Model.Ui.PointBStatusLabel, 'Point B', obj.Model.State.marks.mark1);
            obj.syncReferenceStatus(obj.Model.Ui.PointCStatusLabel, 'Point C', obj.Model.State.marks.mark2);

            obj.Model.Ui.LevelingModeLabel.Text = '3-Point Plane';
            obj.Model.Ui.LevelTiltXValueLabel.Text = '-';
            obj.Model.Ui.LevelTiltYValueLabel.Text = '-';
            obj.Model.Ui.LevelZRangeValueLabel.Text = '-';
            obj.Model.Ui.LevelTiltXValueLabel.Tooltip = '';
            obj.Model.Ui.LevelTiltYValueLabel.Tooltip = '';
            obj.Model.Ui.LevelZRangeValueLabel.Tooltip = '';

            try
                plane = lw_leveling_plane_from_marks(obj.Model.State.marks);
                obj.Model.Ui.LevelTiltXValueLabel.Text = formatSlopeValue(plane.slopeXUmPerMm);
                obj.Model.Ui.LevelTiltYValueLabel.Text = formatSlopeValue(plane.slopeYUmPerMm);
                obj.Model.Ui.LevelTiltXValueLabel.Tooltip = 'Fitted plane slope along X.';
                obj.Model.Ui.LevelTiltYValueLabel.Tooltip = 'Fitted plane slope along Y.';

                if ~isempty(obj.Model.Trajectory)
                    originDisplay = obj.readOriginDisplay();
                    originStage = struct( ...
                        'x', originDisplay.x, ...
                        'y', obj.Ports.displayYToStage(originDisplay.y), ...
                        'z', originDisplay.z);
                    offsetsUm = 1e3 * levelingOffsetForPlane(plane, obj.Model.Trajectory.x, obj.Model.Trajectory.y, originStage);
                    minOffsetUm = min(offsetsUm);
                    maxOffsetUm = max(offsetsUm);
                    spanUm = maxOffsetUm - minOffsetUm;
                    obj.Model.Ui.LevelZRangeValueLabel.Text = sprintf('%s to %s', ...
                        formatMicronValue(minOffsetUm), formatMicronValue(maxOffsetUm));
                    obj.Model.Ui.LevelZRangeValueLabel.Tooltip = sprintf('Span across current plan: %.1f um', spanUm);
                else
                    obj.Model.Ui.LevelZRangeValueLabel.Text = 'No plan loaded';
                    obj.Model.Ui.LevelZRangeValueLabel.Tooltip = 'Load or generate a plan to estimate the leveling correction range.';
                end
            catch ME
                if obj.hasAllLevelingPoints()
                    obj.Model.Ui.LevelTiltXValueLabel.Text = 'Invalid points';
                    obj.Model.Ui.LevelTiltYValueLabel.Text = 'Invalid points';
                    obj.Model.Ui.LevelZRangeValueLabel.Text = 'Invalid points';
                    obj.Model.Ui.LevelTiltXValueLabel.Tooltip = ME.message;
                    obj.Model.Ui.LevelTiltYValueLabel.Tooltip = ME.message;
                    obj.Model.Ui.LevelZRangeValueLabel.Tooltip = ME.message;
                end
            end
        end

        function syncReferenceStatus(obj, labelHandle, labelText, markValue)
            isCaptured = ~isempty(markValue) && numel(markValue) == 3 && all(isfinite(markValue));
            labelHandle.Text = sprintf('%s: %s', labelText, ternary(isCaptured, 'Captured', 'Missing'));
            if isCaptured
                labelHandle.FontColor = [0.1, 0.55, 0.2];
                labelHandle.Tooltip = sprintf('X %.3f, Y %.3f, Z %.3f mm', ...
                    markValue(1), obj.Ports.stageYToDisplay(markValue(2)), markValue(3));
            else
                labelHandle.FontColor = [0.72, 0.2, 0.2];
                labelHandle.Tooltip = 'Not captured yet.';
            end
        end

        function syncSourceModeUi(obj)
            sourceMode = obj.selectedSourceMode();
            switch sourceMode
                case "Imported Points"
                    obj.Model.Ui.InputFileLabel.Text = 'Input File';
                    obj.Model.Ui.InputFileField.Editable = 'on';
                    obj.Model.Ui.BrowseInputFileButton.Enable = 'on';
                    setVisibility(obj.Model.Ui.BrowseInputFileButton, true);
                    setVisibility([obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField, ...
                        obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField, ...
                        obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], false);
                    obj.Model.Ui.PlanPowerLabel.Text = 'XYZ-only Power (%)';
                    obj.Model.Ui.PlanPowerField.Tooltip = 'Used only for XYZ files that do not contain a fourth power column';
                    setVisibility([obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], true);
                    obj.Model.Ui.SourceGrid.RowHeight = {90, 'fit', 'fit', 0, 0, 0, 0, 'fit', 'fit'};
                    obj.Model.Ui.ImportGenerateButton.Text = 'Import Plan';
                    obj.Model.Ui.TransformHintLabel.Text = 'XYZP and writing plans use file power; XYZ-only files use the fixed power above.';

                case "Mark Text"
                    obj.Model.Ui.InputFileLabel.Text = 'Notes';
                    obj.Model.Ui.InputFileField.Editable = 'off';
                    obj.Model.Ui.BrowseInputFileButton.Enable = 'off';
                    setVisibility(obj.Model.Ui.BrowseInputFileButton, false);
                    obj.Model.Ui.ColumnXLabel.Text = 'Mark Text';
                    obj.Model.Ui.ColumnYLabel.Text = 'Pitch (mm)';
                    setVisibility([obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField], true);
                    setVisibility([obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField], false);
                    obj.Model.Ui.PlanPowerLabel.Text = 'Power (%)';
                    obj.Model.Ui.PlanPowerField.Tooltip = 'Execution power stored in the generated Mark Text plan';
                    setVisibility([obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], true);
                    obj.Model.Ui.SourceGrid.RowHeight = {90, 'fit', 0, 'fit', 'fit', 0, 0, 'fit', 'fit'};
                    obj.Model.Ui.ImportGenerateButton.Text = 'Generate Mark';
                    obj.Model.Ui.TransformHintLabel.Text = 'Mark Text stores the power above in the generated plan.';

                case "Frame"
                    obj.Model.Ui.InputFileLabel.Text = 'Notes';
                    obj.Model.Ui.InputFileField.Editable = 'off';
                    obj.Model.Ui.BrowseInputFileButton.Enable = 'off';
                    setVisibility(obj.Model.Ui.BrowseInputFileButton, false);
                    obj.Model.Ui.ColumnXLabel.Text = 'Points X (M)';
                    obj.Model.Ui.ColumnYLabel.Text = 'Points Y (N)';
                    obj.Model.Ui.ColumnZLabel.Text = 'Pitch X (mm)';
                    obj.Model.Ui.ColumnPLabel.Text = 'Pitch Y (mm)';
                    setVisibility([obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField, ...
                        obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField], true);
                    obj.Model.Ui.PlanPowerLabel.Text = 'Power (%)';
                    obj.Model.Ui.PlanPowerField.Tooltip = 'Execution power stored in the generated Frame plan';
                    setVisibility([obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], true);
                    obj.Model.Ui.SourceGrid.RowHeight = {90, 'fit', 0, 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
                    obj.Model.Ui.ImportGenerateButton.Text = 'Generate Frame';
                    obj.Model.Ui.TransformHintLabel.Text = 'Frame stores the power above in the generated plan.';

                otherwise
                    obj.Model.Ui.InputFileLabel.Text = 'G-code File';
                    obj.Model.Ui.InputFileField.Editable = 'on';
                    obj.Model.Ui.BrowseInputFileButton.Enable = 'on';
                    setVisibility(obj.Model.Ui.BrowseInputFileButton, true);
                    obj.Model.Ui.ImportGenerateButton.Text = 'Parse G-code';
                    setVisibility([obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField, ...
                        obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField, ...
                        obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], false);
                    obj.Model.Ui.SourceGrid.RowHeight = {90, 'fit', 'fit', 0, 0, 0, 0, 0, 'fit'};
                    obj.Model.Ui.TransformHintLabel.Text = 'G-code is the next milestone.';
            end
        end

        function syncTrajectoryPreview(obj)
            obj.Ports.clearPreviewColorbar();
            cla(obj.Model.Ui.TrajectoryAxes);
            obj.Model.Ui.PreviewLine = [];
            obj.Model.Ui.PreviewScatter = [];
            obj.Model.Ui.PreviewPositionMarker = [];
            obj.Model.PreviewBounds = struct('x', [], 'y', [], 'z', []);
            obj.Model.Ui.TrajectoryAxes.CLimMode = 'auto';
            hold(obj.Model.Ui.TrajectoryAxes, 'on');
            colormap(obj.Model.Ui.TrajectoryAxes, turbo);

            if obj.Ports.selectedRunMode() == "Z Sweep Mode"
                obj.syncZSweepPreviewContents();
            else
                obj.syncLoadedTrajectoryPreviewContents();
            end

            if isfinite(obj.Model.State.currentPosition.x) && isfinite(obj.Model.State.currentPosition.y) && isfinite(obj.Model.State.currentPosition.z)
                obj.Model.Ui.PreviewPositionMarker = plot3(obj.Model.Ui.TrajectoryAxes, obj.Model.State.currentPosition.x, ...
                    obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), ...
                    obj.Model.State.currentPosition.z, ...
                    'or', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
            end

            hold(obj.Model.Ui.TrajectoryAxes, 'off');
            grid(obj.Model.Ui.TrajectoryAxes, 'on');
            xlabel(obj.Model.Ui.TrajectoryAxes, 'X (mm)');
            ylabel(obj.Model.Ui.TrajectoryAxes, 'Y (mm)');
            zlabel(obj.Model.Ui.TrajectoryAxes, 'Z (mm)');
            obj.Model.Ui.TrajectoryAxes.ZGrid = 'on';
            obj.Ports.apply3DPreviewLimits();
        end

        function syncLoadedTrajectoryPreviewContents(obj)
            if ~isempty(obj.Model.Trajectory) && obj.isCutPlanTrajectory(obj.Model.Trajectory)
                obj.syncCutPlanPreviewContents();
                obj.appendDirtyPlanWarning();
                title(obj.Model.Ui.TrajectoryAxes, 'Cut Plan Preview');
                return;
            end

            if ~isempty(obj.Model.Trajectory)
                xValues = obj.Model.Trajectory.x(:);
                yValues = obj.Ports.stageYToDisplay(obj.Model.Trajectory.y(:));
                zValues = obj.Model.Trajectory.z(:);
                obj.Model.PreviewBounds = struct('x', xValues, 'y', yValues, 'z', zValues);

                if isfield(obj.Model.Trajectory, 'power') && ~isempty(obj.Model.Trajectory.power)
                    powerValues = obj.Model.Trajectory.power(:);
                    if isscalar(powerValues)
                        powerValues = repmat(powerValues, numel(xValues), 1);
                    elseif numel(powerValues) ~= numel(xValues)
                        powerValues = zeros(numel(xValues), 1);
                    end
                else
                    powerValues = zeros(numel(xValues), 1);
                end

                pointCount = numel(xValues);
                previewIndices = lw_preview_sample_indices(pointCount, obj.Model.PreviewMaxPoints);
                previewX = xValues(previewIndices);
                previewY = yValues(previewIndices);
                previewZ = zValues(previewIndices);
                previewPower = powerValues(previewIndices);

                if numel(previewX) > 1
                    obj.Model.Ui.PreviewLine = plot3(obj.Model.Ui.TrajectoryAxes, previewX, previewY, previewZ, '-', ...
                        'Color', [0.55, 0.55, 0.55], 'LineWidth', 0.5);
                end
                obj.Model.Ui.PreviewScatter = scatter3(obj.Model.Ui.TrajectoryAxes, previewX, previewY, previewZ, 18, previewPower, 'filled');
                obj.setColorDataTipLabel(obj.Model.Ui.PreviewScatter, 'Power (%)');
                if numel(previewIndices) < pointCount
                    obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                        'Plan loaded: %d points (sampled preview: %d) | Execution Power %.2f to %.2f %%', ...
                        pointCount, numel(previewIndices), min(powerValues), max(powerValues));
                else
                    obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                        'Plan loaded: %d points | Execution Power %.2f to %.2f %%', ...
                        pointCount, min(powerValues), max(powerValues));
                end
                obj.Model.Ui.PreviewColorbar = colorbar(obj.Model.Ui.TrajectoryAxes);
                obj.Model.Ui.PreviewColorbar.Label.String = 'Power (%)';
            else
                obj.Model.Ui.PreviewNoteLabel.Text = 'Plan: none loaded';
            end

            obj.appendDirtyPlanWarning();

            title(obj.Model.Ui.TrajectoryAxes, 'XYZ Preview');
        end

        function tf = isCutPlanTrajectory(~, traj)
            tf = isfield(traj, 'cutPlan') && istable(traj.cutPlan) && ...
                any(string(traj.cutPlan.mode) == "cut");
        end

        function syncCutPlanPreviewContents(obj)
            cutRows = obj.Model.Trajectory.cutPlan(string(obj.Model.Trajectory.cutPlan.mode) == "cut", :);
            cutGroups = lw_cut_plan_groups(cutRows);
            xValues = [cutRows.leadX; cutRows.x; cutRows.x2; cutRows.exitX];
            yValues = obj.Ports.stageYToDisplay([cutRows.leadY; cutRows.y; cutRows.y2; cutRows.exitY]);
            zValues = [cutRows.leadZ; cutRows.z; cutRows.z2; cutRows.exitZ];
            obj.Model.PreviewBounds = struct('x', xValues, 'y', yValues, 'z', zValues);

            cutCount = height(cutRows);
            groupCount = numel(cutGroups);
            [previewRows, isSampled] = lw_cut_plan_preview_rows(cutRows, obj.Model.PreviewMaxPoints);

            lw_draw_cut_plan_preview_lines(obj.Model.Ui.TrajectoryAxes, previewRows, obj.Ports.stageYToDisplay);
            obj.Model.Ui.PreviewScatter = scatter3(obj.Model.Ui.TrajectoryAxes, previewRows.x, obj.Ports.stageYToDisplay(previewRows.y), ...
                previewRows.z, 22, previewRows.power, 'filled');
            obj.setColorDataTipLabel(obj.Model.Ui.PreviewScatter, 'Power (%)');

            powerValues = cutRows.power;
            if isSampled
                obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                    'Cut plan loaded: %d cuts / %d groups (sampled preview: %d cuts) | Execution Power %.2f to %.2f %%', ...
                    cutCount, groupCount, height(previewRows), min(powerValues), max(powerValues));
            else
                obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                    'Cut plan loaded: %d cuts / %d groups | Execution Power %.2f to %.2f %%', ...
                    cutCount, groupCount, min(powerValues), max(powerValues));
            end
            obj.Model.Ui.PreviewColorbar = colorbar(obj.Model.Ui.TrajectoryAxes);
            obj.Model.Ui.PreviewColorbar.Label.String = 'Power (%)';
        end

        function syncZSweepPreviewContents(obj)
            title(obj.Model.Ui.TrajectoryAxes, 'Z Sweep Preview');
            try
                preview = obj.buildZSweepPreviewFromUi();
            catch ME
                obj.Model.Ui.PreviewNoteLabel.Text = sprintf('Z Sweep preview unavailable: %s', ME.message);
                return;
            end

            if preview.isMatrix
                obj.drawZSweepMatrixPreview(preview);
            else
                obj.drawSingleZSweepPreview(preview.sweep);
            end
        end

        function preview = buildZSweepPreviewFromUi(obj)
            sweep = struct();
            sweep.x = finiteScalar(obj.Model.Ui.ZSweepXField.Value, 'Z Sweep X');
            sweep.displayY = finiteScalar(obj.Model.Ui.ZSweepYField.Value, 'Z Sweep Y');
            sweep.y = obj.Ports.displayYToStage(sweep.displayY);
            sweep.zBack = finiteScalar(obj.Model.Ui.ZSweepBackField.Value, 'Z Sweep Z Back');
            sweep.zFront = finiteScalar(obj.Model.Ui.ZSweepFrontField.Value, 'Z Sweep Z Front');
            sweep.repeatCount = positiveInteger(obj.Model.Ui.ZSweepRepeatField.Value, 'Z Sweep repeat count');
            sweep.sweepSpeedMmPerSecond = positiveScalar(obj.Model.Ui.ZSweepSpeedField.Value, 'Z Sweep speed');
            sweep.returnSpeedMmPerSecond = positiveScalar(obj.Model.Ui.ZSweepReturnSpeedField.Value, 'Z Sweep return speed');
            sweep.powerPercent = validatePowerPercent(obj.Model.Ui.ZSweepPowerField.Value, 'Z Sweep power');
            sweep.exposureDirection = string(obj.Model.Ui.ZSweepDirectionDropDown.Value);

            if abs(sweep.zFront - sweep.zBack) <= 1e-9
                error('Set different Z Back and Z Front values.');
            end

            obj.Ports.validateTargetForUi(struct('x', sweep.x, 'y', sweep.y, 'z', sweep.zBack), 'Z Sweep preview');
            obj.Ports.validateTargetForUi(struct('x', sweep.x, 'y', sweep.y, 'z', sweep.zFront), 'Z Sweep preview');

            preview = struct('isMatrix', obj.Model.Ui.ZSweepMatrixCheckBox.Value, 'sweep', sweep);
            if preview.isMatrix
                preview.matrix = obj.Ports.buildZSweepMatrix(sweep);
            end
        end

        function drawSingleZSweepPreview(obj, sweep)
            exposedColor = [0.95, 0.45, 0.12];
            obj.Model.PreviewBounds = obj.zSweepBoundsFromSweeps(sweep);
            obj.drawZSweepPreviewSweep(sweep, exposedColor, 2.4, true, true);
            obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                'Z Sweep preview: X %.3f | Y %.3f | Z %.3f to %.3f mm | repeat %d | %s | power %.2f %%', ...
                sweep.x, sweep.displayY, min(sweep.zBack, sweep.zFront), max(sweep.zBack, sweep.zFront), ...
                sweep.repeatCount, char(sweep.exposureDirection), sweep.powerPercent);
        end

        function drawZSweepMatrixPreview(obj, preview)
            matrix = preview.matrix;
            obj.Model.PreviewBounds = obj.zSweepBoundsFromSweeps(arrayfun(@(run) run.sweep, matrix.runs));

            totalRuns = matrix.runCount;
            previewIndices = obj.zSweepPreviewRunIndices(totalRuns);
            previewRuns = matrix.runs(previewIndices);
            colorParameter = obj.zSweepPreviewMatrixColorParameter(matrix);
            showReturn = numel(previewRuns) <= 80;

            if colorParameter ~= ""
                colorValues = arrayfun(@(run) obj.zSweepNumericParameterValue(run.sweep, colorParameter), previewRuns);
                colors = obj.zSweepPreviewColors(colorValues);
                colorLimits = obj.zSweepPreviewColorLimits(colorValues);
                clim(obj.Model.Ui.TrajectoryAxes, colorLimits);
            else
                colorValues = [];
                colors = repmat([0.95, 0.45, 0.12], numel(previewRuns), 1);
            end

            for runIndex = 1:numel(previewRuns)
                obj.drawZSweepPreviewSweep(previewRuns(runIndex).sweep, colors(runIndex, :), 1.5, showReturn, true, 4);
            end

            if colorParameter ~= ""
                midX = arrayfun(@(run) run.sweep.x, previewRuns);
                midY = arrayfun(@(run) run.sweep.displayY, previewRuns);
                midZ = arrayfun(@(run) mean([run.sweep.zBack, run.sweep.zFront]), previewRuns);
                obj.Model.Ui.PreviewScatter = scatter3(obj.Model.Ui.TrajectoryAxes, midX, midY, midZ, ...
                    26, colorValues, 'filled', 'MarkerEdgeColor', [0.15, 0.15, 0.15]);
                obj.setColorDataTipLabel(obj.Model.Ui.PreviewScatter, char(colorParameter));
                obj.Model.Ui.PreviewColorbar = colorbar(obj.Model.Ui.TrajectoryAxes);
                obj.Model.Ui.PreviewColorbar.Label.String = char(colorParameter);
            end

            previewText = sprintf('Z Sweep matrix preview: %d rows x %d columns', matrix.rows, matrix.columns);
            if matrix.block.enabled
                previewText = sprintf('%s, %d blocks', previewText, matrix.block.count);
            end
            previewText = sprintf('%s, %d runs', previewText, matrix.runCount);
            if numel(previewIndices) < totalRuns
                previewText = sprintf('%s (previewing %d)', previewText, numel(previewIndices));
            end
            previewText = sprintf('%s | Z %.3f to %.3f mm', ...
                previewText, min(obj.Model.PreviewBounds.z), max(obj.Model.PreviewBounds.z));
            if colorParameter ~= ""
                previewText = sprintf('%s | color = %s', previewText, char(colorParameter));
            end
            obj.Model.Ui.PreviewNoteLabel.Text = previewText;
        end

        function drawZSweepPreviewSweep(obj, sweep, exposedColor, lineWidth, showReturn, showMarkers, markerSize)
            if nargin < 7
                markerSize = 7;
            end
            x = [sweep.x, sweep.x];
            y = [sweep.displayY, sweep.displayY];
            returnColor = [0.48, 0.48, 0.48];

            switch string(sweep.exposureDirection)
                case "Front -> Back"
                    exposedZ = [sweep.zFront, sweep.zBack];
                    returnZ = [sweep.zBack, sweep.zFront];
                    hasReturn = sweep.repeatCount > 1;
                case "Both Directions"
                    exposedZ = [sweep.zBack, sweep.zFront];
                    returnZ = [];
                    hasReturn = false;
                otherwise
                    exposedZ = [sweep.zBack, sweep.zFront];
                    returnZ = [sweep.zFront, sweep.zBack];
                    hasReturn = true;
            end

            plot3(obj.Model.Ui.TrajectoryAxes, x, y, exposedZ, '-', ...
                'Color', exposedColor, 'LineWidth', lineWidth);
            if showReturn && hasReturn
                plot3(obj.Model.Ui.TrajectoryAxes, x, y, returnZ, '--', ...
                    'Color', returnColor, 'LineWidth', max(lineWidth - 0.4, 0.8));
            end

            if showMarkers
                obj.drawZSweepDirectionMarkers(sweep, exposedZ, exposedColor, markerSize);
            end
        end

        function drawZSweepDirectionMarkers(obj, sweep, exposedZ, exposedColor, markerSize)
            plot3(obj.Model.Ui.TrajectoryAxes, sweep.x, sweep.displayY, exposedZ(1), 'o', ...
                'MarkerEdgeColor', exposedColor, 'MarkerFaceColor', [1, 1, 1], 'MarkerSize', markerSize);

            if string(sweep.exposureDirection) == "Both Directions"
                obj.drawZSweepArrowMarker(sweep, [sweep.zBack, sweep.zFront], exposedColor, markerSize);
                obj.drawZSweepArrowMarker(sweep, [sweep.zFront, sweep.zBack], exposedColor, markerSize);
                return;
            end

            obj.drawZSweepArrowMarker(sweep, exposedZ, exposedColor, markerSize);
        end

        function drawZSweepArrowMarker(obj, sweep, zPair, exposedColor, markerSize)
            if zPair(2) >= zPair(1)
                marker = '^';
            else
                marker = 'v';
            end

            plot3(obj.Model.Ui.TrajectoryAxes, sweep.x, sweep.displayY, zPair(2), marker, ...
                'MarkerEdgeColor', exposedColor, 'MarkerFaceColor', exposedColor, 'MarkerSize', markerSize);
        end

        function bounds = zSweepBoundsFromSweeps(~, sweeps)
            xValues = arrayfun(@(sweep) sweep.x, sweeps);
            yValues = arrayfun(@(sweep) sweep.displayY, sweeps);
            zBackValues = arrayfun(@(sweep) sweep.zBack, sweeps);
            zFrontValues = arrayfun(@(sweep) sweep.zFront, sweeps);
            bounds = struct( ...
                'x', xValues(:), ...
                'y', yValues(:), ...
                'z', [zBackValues(:); zFrontValues(:)]);
        end

        function indices = zSweepPreviewRunIndices(obj, runCount)
            if runCount <= obj.Model.ZSweepPreviewMaxRuns
                indices = (1:runCount).';
                return;
            end

            indices = unique(round(linspace(1, runCount, obj.Model.ZSweepPreviewMaxRuns)));
            indices = indices(:);
        end

        function parameter = zSweepPreviewMatrixColorParameter(~, matrix)
            selectedParameters = [matrix.xParameter, matrix.yParameter, matrix.block.parameters];
            preferredParameters = ["Power (%)", "Sweep Speed (mm/s)", "Repeat Count", "Return Speed (mm/s)"];
            parameter = "";
            for parameterIndex = 1:numel(preferredParameters)
                if any(selectedParameters == preferredParameters(parameterIndex))
                    parameter = preferredParameters(parameterIndex);
                    return;
                end
            end
        end

        function value = zSweepNumericParameterValue(~, sweep, parameterName)
            switch string(parameterName)
                case "Power (%)"
                    value = sweep.powerPercent;
                case "Sweep Speed (mm/s)"
                    value = sweep.sweepSpeedMmPerSecond;
                case "Return Speed (mm/s)"
                    value = sweep.returnSpeedMmPerSecond;
                case "Repeat Count"
                    value = sweep.repeatCount;
                otherwise
                    value = nan;
            end
        end

        function colors = zSweepPreviewColors(obj, values)
            values = double(values(:));
            colorMap = turbo(256);
            limits = obj.zSweepPreviewColorLimits(values);
            if diff(limits) <= 0
                colorIndices = repmat(180, numel(values), 1);
            else
                colorIndices = 1 + round((values - limits(1)) ./ diff(limits) * (size(colorMap, 1) - 1));
                colorIndices = max(1, min(size(colorMap, 1), colorIndices));
            end
            colors = colorMap(colorIndices, :);
        end

        function setColorDataTipLabel(~, chartHandle, labelText)
            try
                rows = chartHandle.DataTipTemplate.DataTipRows;
                rowLabels = string({rows.Label});
                colorRowIndex = find(rowLabels == "Color", 1, 'first');
                if isempty(colorRowIndex)
                    return;
                end

                rows(colorRowIndex).Label = char(labelText);
                chartHandle.DataTipTemplate.DataTipRows = rows;
            catch
            end
        end

        function limits = zSweepPreviewColorLimits(~, values)
            values = double(values(:));
            values = values(isfinite(values));
            if isempty(values)
                limits = [0, 1];
                return;
            end

            valueMin = min(values);
            valueMax = max(values);
            if abs(valueMax - valueMin) <= eps(max(abs([valueMin, valueMax, 1])))
                pad = max(abs(valueMin) * 0.05, 1);
                limits = [valueMin - pad, valueMax + pad];
            else
                limits = [valueMin, valueMax];
            end
        end

        function syncPreviewCurrentPosition(obj)
            hasPosition = isfinite(obj.Model.State.currentPosition.x) && ...
                isfinite(obj.Model.State.currentPosition.y) && ...
                isfinite(obj.Model.State.currentPosition.z);

            if isempty(obj.Model.Ui.PreviewPositionMarker) || ~isgraphics(obj.Model.Ui.PreviewPositionMarker)
                if ~hasPosition
                    return;
                end

                wasHeld = ishold(obj.Model.Ui.TrajectoryAxes);
                hold(obj.Model.Ui.TrajectoryAxes, 'on');
                obj.Model.Ui.PreviewPositionMarker = plot3(obj.Model.Ui.TrajectoryAxes, obj.Model.State.currentPosition.x, ...
                    obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), ...
                    obj.Model.State.currentPosition.z, ...
                    'or', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
                if ~wasHeld
                    hold(obj.Model.Ui.TrajectoryAxes, 'off');
                end
                return;
            end

            if ~hasPosition
                obj.Model.Ui.PreviewPositionMarker.Visible = 'off';
                return;
            end

            obj.Model.Ui.PreviewPositionMarker.XData = obj.Model.State.currentPosition.x;
            obj.Model.Ui.PreviewPositionMarker.YData = obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y);
            obj.Model.Ui.PreviewPositionMarker.ZData = obj.Model.State.currentPosition.z;
            obj.Model.Ui.PreviewPositionMarker.Visible = 'on';
        end

        function appendDirtyPlanWarning(obj)
            if isempty(obj.Model.Trajectory) || ~obj.Model.TrajectoryInputsDirty
                return;
            end
            obj.Model.Ui.PreviewNoteLabel.Text = sprintf('%s | POWER INPUT CHANGED - regenerate or re-import before running', ...
                char(string(obj.Model.Ui.PreviewNoteLabel.Text)));
        end

        function tf = currentSourceMatchesLoadedTrajectory(obj)
            tf = false;
            if isempty(obj.Model.Trajectory) || ~isfield(obj.Model.Trajectory, 'sourceType')
                return;
            end

            sourceType = string(obj.Model.Trajectory.sourceType);
            switch obj.selectedSourceMode()
                case "Imported Points"
                    tf = any(sourceType == ["imported_points", "writing_plan"]);
                case "Mark Text"
                    tf = sourceType == "mark_text";
                case "Frame"
                    tf = sourceType == "frame";
            end
        end

        function mode = selectedSourceMode(obj)
            mode = string(obj.Model.Ui.SourceModeGroup.SelectedObject.Text);
        end

        function origin = readOriginDisplay(obj)
            origin = struct( ...
                'x', obj.Model.Ui.StartXField.Value, ...
                'y', obj.Model.Ui.StartYField.Value, ...
                'z', obj.Model.Ui.StartZField.Value);
        end

        function magnification = readMagnification(obj)
            magnification = struct( ...
                'x', positiveScalar(obj.Model.Ui.MagnificationXField.Value, 'Mx'), ...
                'y', positiveScalar(obj.Model.Ui.MagnificationYField.Value, 'My'), ...
                'z', positiveScalar(obj.Model.Ui.MagnificationZField.Value, 'Mz'));
        end

        function tf = hasAllLevelingPoints(obj)
            tf = ~isempty(obj.Model.State.marks.mark0) && ...
                ~isempty(obj.Model.State.marks.mark1) && ...
                ~isempty(obj.Model.State.marks.mark2);
        end

    end
end
