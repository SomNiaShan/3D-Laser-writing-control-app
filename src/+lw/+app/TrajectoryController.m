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
                "apply3DPreviewLimits", "clearPreviewColorbar", ...
                "displayYToStage", "logMessage", "runUiAction", ...
                "stageLaser", "stageYToDisplay", "syncAll", "validateTargetForUi"]);
        end

        function initializeSourceModeMemory(obj)
            obj.Model.SourceModeMemory = struct( ...
                'importedPoints', obj.sourceModeFields('', '', '', '', '', 10, false), ...
                'markText', obj.sourceModeFields('', 'TEXT', '0.01', '', '', 10, false), ...
                'frame', obj.sourceModeFields('Outer ring of an MxN point grid', '10', '10', '0.01', '0.01', 10, false), ...
                'gcode', obj.sourceModeFields('', '', '', '', '', 10, false));
            obj.Model.CurrentSourceMode = obj.selectedSourceMode();
            obj.restoreSourceModeFields(obj.Model.CurrentSourceMode);
        end

        function values = sourceModeFields(~, inputFile, columnX, columnY, columnZ, columnP, planPower, useFixedPower)
            values = struct( ...
                'inputFile', string(inputFile), ...
                'columnX', string(columnX), ...
                'columnY', string(columnY), ...
                'columnZ', string(columnZ), ...
                'columnP', string(columnP), ...
                'planPower', double(planPower), ...
                'useFixedPower', logical(useFixedPower));
        end

        function saveSourceModeFields(obj, mode)
            obj.Model.SourceModeMemory.(obj.sourceModeStorageKey(mode)) = obj.sourceModeFields( ...
                obj.Model.Ui.InputFileField.Value, ...
                obj.Model.Ui.ColumnXField.Value, ...
                obj.Model.Ui.ColumnYField.Value, ...
                obj.Model.Ui.ColumnZField.Value, ...
                obj.Model.Ui.ColumnPField.Value, ...
                obj.Model.Ui.PlanPowerField.Value, ...
                obj.Model.Ui.UseFixedPowerCheckBox.Value);
        end

        function restoreSourceModeFields(obj, mode)
            values = obj.Model.SourceModeMemory.(obj.sourceModeStorageKey(mode));
            obj.Model.Ui.InputFileField.Value = values.inputFile;
            obj.Model.Ui.ColumnXField.Value = values.columnX;
            obj.Model.Ui.ColumnYField.Value = values.columnY;
            obj.Model.Ui.ColumnZField.Value = values.columnZ;
            obj.Model.Ui.ColumnPField.Value = values.columnP;
            obj.Model.Ui.PlanPowerField.Value = values.planPower;
            obj.Model.Ui.UseFixedPowerCheckBox.Value = values.useFixedPower;
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
            obj.markPreparedPlanDirty("Plan input file changed - prepare again");
            obj.Ports.logMessage(sprintf('Selected input file: %s', obj.Model.Ui.InputFileField.Value));
        end

        function onSourceModeChanged(obj, ~, ~)
            if obj.Model.CurrentSourceMode ~= "Z Sweep"
                obj.saveSourceModeFields(obj.Model.CurrentSourceMode);
            end
            obj.Model.CurrentSourceMode = obj.selectedSourceMode();
            if obj.Model.CurrentSourceMode ~= "Z Sweep"
                obj.restoreSourceModeFields(obj.Model.CurrentSourceMode);
            end
            obj.markPreparedPlanDirty("Plan source changed - prepare again");
            obj.Ports.syncAll();
        end

        function onPlanInputChanged(obj, ~, ~)
            obj.markPreparedPlanDirty("Plan inputs changed - prepare again");
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

        function onFixedPowerOverrideChanged(obj, ~, ~)
            if ~isempty(obj.Model.Trajectory) && obj.currentSourceMatchesLoadedTrajectory()
                obj.Model.TrajectoryInputsDirty = true;
                obj.Model.RunCurrentText = "Fixed-power setting changed - re-import";
                obj.Ports.logMessage( ...
                    'Fixed-power override changed; re-import the plan before running.');
            end
            obj.Ports.syncAll();
        end

        function onZSweepPreviewChanged(obj, ~, ~)
            obj.markPreparedPlanDirty("Z Sweep inputs changed - prepare again");
            obj.Ports.syncAll();
        end

        function onZSweepMatrixChanged(obj, ~, ~)
            obj.markPreparedPlanDirty("Z Sweep matrix changed - prepare again");
            obj.Ports.syncAll();
        end

        function onImportOrGenerateTrajectory(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.importTrajectoryImpl(), 'Failed while preparing plan');
        end

        function importTrajectoryImpl(obj)
            if obj.selectedSourceMode() == "Z Sweep"
                obj.prepareZSweepPlanImpl();
                return;
            end

            obj.Model.Trajectory = obj.buildTrajectoryFromUi();
            obj.Model.State.trajectory = obj.Model.Trajectory;
            obj.Model.PreparedPlan = obj.preparedTrajectoryPlan( ...
                obj.Model.Trajectory, obj.selectedSourceMode());
            obj.Model.TrajectoryInputsDirty = false;
            obj.Model.RunProgressText = sprintf('0 / %d', numel(obj.Model.Trajectory.x));
            obj.Model.RunCurrentText = "Plan prepared";
            obj.Ports.logMessage(sprintf('Plan ready: %d points, source = %s.', ...
                numel(obj.Model.Trajectory.x), char(obj.Model.Trajectory.sourceType)));
        end

        function prepareZSweepPlanImpl(obj)
            plan = obj.buildZSweepPlanFromUi();
            obj.Model.PreparedPlan = plan;
            obj.Model.Trajectory = [];
            obj.Model.State.trajectory = [];
            obj.Model.TrajectoryInputsDirty = false;
            obj.Model.RunProgressText = sprintf('0 / %d', plan.progressTotal);
            obj.Model.RunCurrentText = "Z Sweep plan prepared";
            if plan.isMatrix
                obj.Ports.logMessage(sprintf( ...
                    'Z Sweep matrix plan ready: %d run(s), %d exposed sweep(s).', ...
                    numel(plan.sweepJobs), plan.exposedSweepCount));
            else
                obj.Ports.logMessage(sprintf( ...
                    'Z Sweep plan ready: %d exposed sweep(s).', ...
                    plan.exposedSweepCount));
            end
        end

        function out = buildTrajectoryFromUi(obj)
            sourceMode = obj.selectedSourceMode();
            switch sourceMode
                case "Imported Points"
                    filename = strtrim(string(obj.Model.Ui.InputFileField.Value));
                    if filename == ""
                        error('Please select an input file first.');
                    end

                    out = lw_import_points_table( ...
                        filename, ...
                        obj.Model.Ui.UseFixedPowerCheckBox.Value, ...
                        obj.Model.Ui.PlanPowerField.Value);

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
            if ~isfield(out, 'writingPlan') || ~istable(out.writingPlan)
                return;
            end

            yFields = {'y', 'y2'};
            for i = 1:numel(yFields)
                fieldName = yFields{i};
                if ismember(fieldName, out.writingPlan.Properties.VariableNames)
                    out.writingPlan.(fieldName) = ...
                        obj.Ports.displayYToStage(out.writingPlan.(fieldName));
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
            normalControls = { ...
                obj.Model.Ui.InputFileLabel, obj.Model.Ui.InputFileField, ...
                obj.Model.Ui.BrowseInputFileButton, ...
                obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, ...
                obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField, ...
                obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, ...
                obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField, ...
                obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.UseFixedPowerCheckBox, ...
                obj.Model.Ui.PlanPowerField, obj.Model.Ui.PlacementSectionLabel, ...
                obj.Model.Ui.StartXLabel, obj.Model.Ui.StartXField, ...
                obj.Model.Ui.MagnificationXLabel, obj.Model.Ui.MagnificationXField, ...
                obj.Model.Ui.StartYLabel, obj.Model.Ui.StartYField, ...
                obj.Model.Ui.MagnificationYLabel, obj.Model.Ui.MagnificationYField, ...
                obj.Model.Ui.StartZLabel, obj.Model.Ui.StartZField, ...
                obj.Model.Ui.MagnificationZLabel, obj.Model.Ui.MagnificationZField, ...
                obj.Model.Ui.UseCurrentOriginButton, obj.Model.Ui.TransformHintLabel, ...
                obj.Model.Ui.EnableZCompensationCheckBox, ...
                obj.Model.Ui.PointExposureLabel, obj.Model.Ui.PointExposureField, ...
                obj.Model.Ui.PointPauseLabel, obj.Model.Ui.PointPauseField};
            zSweepControls = { ...
                obj.Model.Ui.ZSweepPowerLabel, obj.Model.Ui.ZSweepPowerField, ...
                obj.Model.Ui.ZSweepDirectionLabel, obj.Model.Ui.ZSweepDirectionDropDown, ...
                obj.Model.Ui.ZSweepXLabel, obj.Model.Ui.ZSweepXField, ...
                obj.Model.Ui.ZSweepYLabel, obj.Model.Ui.ZSweepYField, ...
                obj.Model.Ui.ZSweepBackLabel, obj.Model.Ui.ZSweepBackField, ...
                obj.Model.Ui.ZSweepFrontLabel, obj.Model.Ui.ZSweepFrontField, ...
                obj.Model.Ui.ZSweepSpeedLabel, obj.Model.Ui.ZSweepSpeedField, ...
                obj.Model.Ui.ZSweepReturnSpeedLabel, obj.Model.Ui.ZSweepReturnSpeedField, ...
                obj.Model.Ui.ZSweepRepeatLabel, obj.Model.Ui.ZSweepRepeatField, ...
                obj.Model.Ui.ZSweepUseCurrentButton, ...
                obj.Model.Ui.ZSweepMatrixCheckBox, obj.Model.Ui.ZSweepMatrixHintLabel, ...
                obj.Model.Ui.ZSweepMatrixXParamLabel, obj.Model.Ui.ZSweepMatrixXParamDropDown, ...
                obj.Model.Ui.ZSweepMatrixYParamLabel, obj.Model.Ui.ZSweepMatrixYParamDropDown, ...
                obj.Model.Ui.ZSweepMatrixXValuesLabel, obj.Model.Ui.ZSweepMatrixXValuesField, ...
                obj.Model.Ui.ZSweepMatrixYValuesLabel, obj.Model.Ui.ZSweepMatrixYValuesField, ...
                obj.Model.Ui.ZSweepPitchXLabel, obj.Model.Ui.ZSweepPitchXField, ...
                obj.Model.Ui.ZSweepPitchYLabel, obj.Model.Ui.ZSweepPitchYField, ...
                obj.Model.Ui.ZSweepBlockCheckBox, obj.Model.Ui.ZSweepBlockHintLabel, ...
                obj.Model.Ui.ZSweepBlockParam1Label, obj.Model.Ui.ZSweepBlockParam1DropDown, ...
                obj.Model.Ui.ZSweepBlockValues1Label, obj.Model.Ui.ZSweepBlockValues1Field, ...
                obj.Model.Ui.ZSweepBlockParam2Label, obj.Model.Ui.ZSweepBlockParam2DropDown, ...
                obj.Model.Ui.ZSweepBlockValues2Label, obj.Model.Ui.ZSweepBlockValues2Field, ...
                obj.Model.Ui.ZSweepBlockPitchXLabel, obj.Model.Ui.ZSweepBlockPitchXField, ...
                obj.Model.Ui.ZSweepBlockPitchYLabel, obj.Model.Ui.ZSweepBlockPitchYField};

            isZSweep = sourceMode == "Z Sweep";
            setVisibility(normalControls, ~isZSweep);
            setVisibility(zSweepControls, isZSweep);
            setVisibility(obj.Model.Ui.ImportGenerateButton, true);
            obj.Model.Ui.ImportGenerateButton.Layout.Row = ternary(isZSweep, 15, 7);
            if isZSweep
                rowHeights = repmat({'fit'}, 1, 16);
                rowHeights{1} = 82;
                if ~obj.Model.Ui.ZSweepMatrixCheckBox.Value
                    rowHeights(8:14) = {0};
                elseif ~obj.Model.Ui.ZSweepBlockCheckBox.Value
                    rowHeights(12:14) = {0};
                end
                obj.Model.Ui.PlanBuilderGrid.RowHeight = rowHeights;
                obj.Model.Ui.ImportGenerateButton.Text = 'Prepare Z Sweep Plan';
                obj.Model.Ui.PlanBuilderHintLabel.Text = ...
                    ['Z Sweep is prepared and previewed here. Run executes ', ...
                    'the frozen sweep or matrix without another mode choice.'];
                return;
            end

            rowHeights = {82, 'fit', 'fit', 0, 0, 'fit', 'fit', ...
                'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};
            switch sourceMode
                case "Imported Points"
                    obj.Model.Ui.InputFileLabel.Text = 'Input File';
                    obj.Model.Ui.InputFileField.Editable = 'on';
                    obj.Model.Ui.BrowseInputFileButton.Enable = 'on';
                    setVisibility(obj.Model.Ui.BrowseInputFileButton, true);
                    setVisibility([obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField, ...
                        obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField, ...
                        obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.UseFixedPowerCheckBox, obj.Model.Ui.PlanPowerField], false);
                    obj.Model.Ui.UseFixedPowerCheckBox.Text = 'Use Fixed Power (%)';
                    obj.Model.Ui.UseFixedPowerCheckBox.Tooltip = ...
                        'Ignore every file power value and use the fixed power for all imported operations';
                    obj.Model.Ui.PlanPowerField.Tooltip = ...
                        'Fixed execution power used for every imported operation when enabled';
                    setVisibility([obj.Model.Ui.UseFixedPowerCheckBox, obj.Model.Ui.PlanPowerField], true);
                    obj.Model.Ui.ImportGenerateButton.Text = 'Import Plan';
                    obj.Model.Ui.TransformHintLabel.Text = ...
                        'Use Fixed Power overrides every imported power value; otherwise the file power is used.';

                case "Mark Text"
                    obj.Model.Ui.InputFileLabel.Text = 'Notes';
                    obj.Model.Ui.InputFileField.Editable = 'off';
                    obj.Model.Ui.BrowseInputFileButton.Enable = 'off';
                    setVisibility(obj.Model.Ui.BrowseInputFileButton, false);
                    obj.Model.Ui.ColumnXLabel.Text = 'Mark Text';
                    obj.Model.Ui.ColumnYLabel.Text = 'Pitch (mm)';
                    setVisibility([obj.Model.Ui.ColumnXLabel, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYLabel, obj.Model.Ui.ColumnYField], true);
                    setVisibility([obj.Model.Ui.ColumnZLabel, obj.Model.Ui.ColumnZField, obj.Model.Ui.ColumnPLabel, obj.Model.Ui.ColumnPField], false);
                    setVisibility(obj.Model.Ui.UseFixedPowerCheckBox, false);
                    obj.Model.Ui.PlanPowerLabel.Text = 'Power (%)';
                    obj.Model.Ui.PlanPowerField.Tooltip = 'Execution power stored in the generated Mark Text plan';
                    setVisibility([obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], true);
                    rowHeights{3} = 0;
                    rowHeights{4} = 'fit';
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
                    setVisibility(obj.Model.Ui.UseFixedPowerCheckBox, false);
                    obj.Model.Ui.PlanPowerLabel.Text = 'Power (%)';
                    obj.Model.Ui.PlanPowerField.Tooltip = 'Execution power stored in the generated Frame plan';
                    setVisibility([obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.PlanPowerField], true);
                    rowHeights{3} = 0;
                    rowHeights{4} = 'fit';
                    rowHeights{5} = 'fit';
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
                        obj.Model.Ui.PlanPowerLabel, obj.Model.Ui.UseFixedPowerCheckBox, obj.Model.Ui.PlanPowerField], false);
                    obj.Model.Ui.TransformHintLabel.Text = 'G-code is the next milestone.';
            end
            obj.Model.Ui.PlanBuilderGrid.RowHeight = rowHeights;
            obj.Model.Ui.PlanBuilderHintLabel.Text = ...
                ['Point and Path execution are inferred from the prepared plan. ', ...
                'The Run tab does not override this choice.'];
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

            if obj.selectedSourceMode() == "Z Sweep"
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
            if ~isempty(obj.Model.Trajectory) && obj.isPathPlanTrajectory(obj.Model.Trajectory)
                obj.syncPathPlanPreviewContents();
                obj.appendDirtyPlanWarning();
                title(obj.Model.Ui.TrajectoryAxes, 'Path Plan Preview');
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
                obj.Model.Ui.PreviewNoteLabel.Text = 'Plan: none prepared';
            end

            obj.appendDirtyPlanWarning();

            title(obj.Model.Ui.TrajectoryAxes, 'XYZ Preview');
        end

        function tf = isPathPlanTrajectory(~, traj)
            tf = isfield(traj, 'writingPlan') && istable(traj.writingPlan) && ...
                any(string(traj.writingPlan.operation) == "path");
        end

        function syncPathPlanPreviewContents(obj)
            pathRows = obj.Model.Trajectory.writingPlan( ...
                string(obj.Model.Trajectory.writingPlan.operation) == "path", :);
            pathGroups = lw_path_plan_groups(pathRows);
            xValues = [pathRows.x; pathRows.x2];
            yValues = obj.Ports.stageYToDisplay([pathRows.y; pathRows.y2]);
            zValues = [pathRows.z; pathRows.z2];
            obj.Model.PreviewBounds = struct('x', xValues, 'y', yValues, 'z', zValues);

            segmentCount = height(pathRows);
            groupCount = numel(pathGroups);
            [previewRows, isSampled] = lw_path_plan_preview_rows( ...
                pathRows, obj.Model.PreviewMaxPoints);

            lw_draw_path_plan_preview_lines( ...
                obj.Model.Ui.TrajectoryAxes, previewRows, obj.Ports.stageYToDisplay);
            obj.Model.Ui.PreviewScatter = scatter3(obj.Model.Ui.TrajectoryAxes, previewRows.x, obj.Ports.stageYToDisplay(previewRows.y), ...
                previewRows.z, 22, previewRows.power, 'filled');
            obj.setColorDataTipLabel(obj.Model.Ui.PreviewScatter, 'Power (%)');

            powerValues = pathRows.power;
            if isSampled
                obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                    'Path plan loaded: %d segments / %d groups (sampled preview: %d segments) | Execution Power %.2f to %.2f %%', ...
                    segmentCount, groupCount, height(previewRows), min(powerValues), max(powerValues));
            else
                obj.Model.Ui.PreviewNoteLabel.Text = sprintf( ...
                    'Path plan loaded: %d segments / %d groups | Execution Power %.2f to %.2f %%', ...
                    segmentCount, groupCount, min(powerValues), max(powerValues));
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
            obj.appendDirtyPlanWarning();
        end

        function preview = buildZSweepPreviewFromUi(obj)
            plan = obj.buildZSweepPlanFromUi();
            preview = struct( ...
                'isMatrix', plan.isMatrix, ...
                'sweep', plan.sweep);
            if plan.isMatrix
                preview.matrix = plan.matrix;
            end
        end

        function plan = buildZSweepPlanFromUi(obj)
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

            isMatrix = logical(obj.Model.Ui.ZSweepMatrixCheckBox.Value);
            plan = struct( ...
                'kind', "z_sweep", ...
                'sourceMode', "Z Sweep", ...
                'sourceType', "z_sweep", ...
                'isMatrix', isMatrix, ...
                'sweep', sweep, ...
                'sweepJobs', singleZSweepJob(sweep), ...
                'progressTotal', zSweepProgressTotal(sweep), ...
                'exposedSweepCount', zSweepExposedSweepCount(sweep));
            if isMatrix
                plan.matrix = obj.buildZSweepMatrix(sweep);
                plan.sweepJobs = plan.matrix.runs;
                plan.progressTotal = plan.matrix.progressTotal;
                plan.exposedSweepCount = plan.matrix.exposedSweepCount;
            end
        end

        function matrix = buildZSweepMatrix(obj, baseSweep)
            xParameter = string(obj.Model.Ui.ZSweepMatrixXParamDropDown.Value);
            yParameter = string(obj.Model.Ui.ZSweepMatrixYParamDropDown.Value);
            xValues = zSweepMatrixParameterValues( ...
                xParameter, obj.Model.Ui.ZSweepMatrixXValuesField.Value);
            yValues = zSweepMatrixParameterValues( ...
                yParameter, obj.Model.Ui.ZSweepMatrixYValuesField.Value);
            pitchX = positiveScalar( ...
                obj.Model.Ui.ZSweepPitchXField.Value, 'Z Sweep matrix pitch X');
            pitchY = positiveScalar( ...
                obj.Model.Ui.ZSweepPitchYField.Value, 'Z Sweep matrix pitch Y');
            blockConfig = obj.zSweepMatrixBlockConfig();
            validateUniqueZSweepMatrixParameters( ...
                [xParameter, yParameter, blockConfig.parameters]);

            runCount = numel(xValues) * numel(yValues) * blockConfig.count;
            runs = repmat(struct( ...
                'index', 0, ...
                'xIndex', 0, ...
                'yIndex', 0, ...
                'blockIndex', 0, ...
                'blockColumn', 1, ...
                'blockRow', 1, ...
                'xValueText', "", ...
                'yValueText', "", ...
                'blockText', "", ...
                'sweep', baseSweep), runCount, 1);

            runIndex = 0;
            progressTotal = 0;
            exposedSweepCount = 0;
            for blockIndex = 1:blockConfig.count
                blockColumn = mod(blockIndex - 1, blockConfig.columns) + 1;
                blockRow = floor((blockIndex - 1) / blockConfig.columns) + 1;
                for yIndex = 1:numel(yValues)
                    for xIndex = 1:numel(xValues)
                        runIndex = runIndex + 1;
                        runSweep = baseSweep;
                        runSweep = applyZSweepBlockParameters( ...
                            runSweep, blockConfig, blockColumn, blockRow);
                        runSweep = applyZSweepMatrixParameter( ...
                            runSweep, xParameter, xValues(xIndex));
                        runSweep = applyZSweepMatrixParameter( ...
                            runSweep, yParameter, yValues(yIndex));
                        runSweep.powerPercent = validatePowerPercent( ...
                            runSweep.powerPercent, 'Z Sweep matrix power');
                        runSweep.x = baseSweep.x + ...
                            (blockColumn - 1) * blockConfig.pitchX + ...
                            (xIndex - 1) * pitchX;
                        runSweep.displayY = baseSweep.displayY + ...
                            (blockRow - 1) * blockConfig.pitchY + ...
                            (yIndex - 1) * pitchY;
                        runSweep.y = obj.Ports.displayYToStage(runSweep.displayY);

                        obj.Ports.validateTargetForUi(struct( ...
                            'x', runSweep.x, 'y', runSweep.y, ...
                            'z', runSweep.zBack), 'Z Sweep matrix');
                        obj.Ports.validateTargetForUi(struct( ...
                            'x', runSweep.x, 'y', runSweep.y, ...
                            'z', runSweep.zFront), 'Z Sweep matrix');

                        runs(runIndex) = struct( ...
                            'index', runIndex, ...
                            'xIndex', xIndex, ...
                            'yIndex', yIndex, ...
                            'blockIndex', blockIndex, ...
                            'blockColumn', blockColumn, ...
                            'blockRow', blockRow, ...
                            'xValueText', zSweepMatrixValueText( ...
                                xParameter, xValues(xIndex)), ...
                            'yValueText', zSweepMatrixValueText( ...
                                yParameter, yValues(yIndex)), ...
                            'blockText', zSweepBlockText( ...
                                blockConfig, blockIndex), ...
                            'sweep', runSweep);
                        progressTotal = progressTotal + ...
                            zSweepProgressTotal(runSweep);
                        exposedSweepCount = exposedSweepCount + ...
                            zSweepExposedSweepCount(runSweep);
                    end
                end
            end

            runXValues = arrayfun(@(run) run.sweep.x, runs);
            displayYValues = arrayfun(@(run) run.sweep.displayY, runs);
            matrix = struct( ...
                'xParameter', xParameter, ...
                'yParameter', yParameter, ...
                'xValues', xValues, ...
                'yValues', yValues, ...
                'pitchX', pitchX, ...
                'pitchY', pitchY, ...
                'block', blockConfig, ...
                'rows', numel(yValues), ...
                'columns', numel(xValues), ...
                'runCount', runCount, ...
                'runs', runs, ...
                'xRange', [min(runXValues), max(runXValues)], ...
                'displayYRange', [min(displayYValues), max(displayYValues)], ...
                'progressTotal', progressTotal, ...
                'exposedSweepCount', exposedSweepCount);
        end

        function blockConfig = zSweepMatrixBlockConfig(obj)
            if ~obj.Model.Ui.ZSweepBlockCheckBox.Value
                blockConfig = struct( ...
                    'enabled', false, ...
                    'xParameter', "None", ...
                    'yParameter', "None", ...
                    'xValues', [], ...
                    'yValues', [], ...
                    'parameters', strings(1, 0), ...
                    'values', {{}}, ...
                    'count', 1, ...
                    'columns', 1, ...
                    'rows', 1, ...
                    'pitchX', 0, ...
                    'pitchY', 0);
                return;
            end

            xParameter = string(obj.Model.Ui.ZSweepBlockParam1DropDown.Value);
            yParameter = string(obj.Model.Ui.ZSweepBlockParam2DropDown.Value);
            xValues = [];
            yValues = [];
            selectedParameters = strings(1, 0);
            selectedValues = {};

            if xParameter ~= "None"
                xValues = zSweepMatrixParameterValues( ...
                    xParameter, obj.Model.Ui.ZSweepBlockValues1Field.Value);
                selectedParameters(end + 1) = xParameter;
                selectedValues{end + 1} = xValues;
            end
            if yParameter ~= "None"
                yValues = zSweepMatrixParameterValues( ...
                    yParameter, obj.Model.Ui.ZSweepBlockValues2Field.Value);
                selectedParameters(end + 1) = yParameter;
                selectedValues{end + 1} = yValues;
            end
            if isempty(selectedParameters)
                error(['Z Sweep matrix blocks are enabled, but no block ', ...
                    'parameter is selected.']);
            end

            blockColumns = 1;
            blockRows = 1;
            if xParameter ~= "None"
                blockColumns = numel(xValues);
            end
            if yParameter ~= "None"
                blockRows = numel(yValues);
            end
            blockConfig = struct( ...
                'enabled', true, ...
                'xParameter', xParameter, ...
                'yParameter', yParameter, ...
                'xValues', xValues, ...
                'yValues', yValues, ...
                'parameters', selectedParameters, ...
                'values', {selectedValues}, ...
                'count', blockColumns * blockRows, ...
                'columns', blockColumns, ...
                'rows', blockRows, ...
                'pitchX', positiveScalar( ...
                    obj.Model.Ui.ZSweepBlockPitchXField.Value, ...
                    'Z Sweep block pitch X'), ...
                'pitchY', positiveScalar( ...
                    obj.Model.Ui.ZSweepBlockPitchYField.Value, ...
                    'Z Sweep block pitch Y'));
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
            if isempty(obj.Model.PreparedPlan) || ~obj.Model.TrajectoryInputsDirty
                return;
            end
            obj.Model.Ui.PreviewNoteLabel.Text = sprintf('%s | INPUTS CHANGED - prepare the plan again before running', ...
                char(string(obj.Model.Ui.PreviewNoteLabel.Text)));
        end

        function updateZSweepMatrixParameterEnableStates(obj, isMatrixEnabled)
            selectedParameters = strings(1, 0);
            if isMatrixEnabled
                selectedParameters = [ ...
                    string(obj.Model.Ui.ZSweepMatrixXParamDropDown.Value), ...
                    string(obj.Model.Ui.ZSweepMatrixYParamDropDown.Value)];
                if obj.Model.Ui.ZSweepBlockCheckBox.Value
                    selectedParameters = [ ...
                        selectedParameters, obj.zSweepSelectedBlockParameters()];
                end
            end

            obj.setSingleParameterEnableState('Power (%)', ...
                {obj.Model.Ui.ZSweepPowerLabel, obj.Model.Ui.ZSweepPowerField}, ...
                selectedParameters);
            obj.setSingleParameterEnableState('Sweep Speed (mm/s)', ...
                {obj.Model.Ui.ZSweepSpeedLabel, obj.Model.Ui.ZSweepSpeedField}, ...
                selectedParameters);
            obj.setSingleParameterEnableState('Return Speed (mm/s)', ...
                {obj.Model.Ui.ZSweepReturnSpeedLabel, ...
                obj.Model.Ui.ZSweepReturnSpeedField}, selectedParameters);
            obj.setSingleParameterEnableState('Repeat Count', ...
                {obj.Model.Ui.ZSweepRepeatLabel, obj.Model.Ui.ZSweepRepeatField}, ...
                selectedParameters);
            obj.setSingleParameterEnableState('Exposure Direction', ...
                {obj.Model.Ui.ZSweepDirectionLabel, ...
                obj.Model.Ui.ZSweepDirectionDropDown}, selectedParameters);
        end

        function setSingleParameterEnableState(obj, parameterName, controls, selectedParameters)
            isSelectedForMatrix = any(selectedParameters == string(parameterName));
            configurationUnlocked = ~obj.Model.State.isBusy && ...
                ~obj.Model.State.isPaused && ~obj.Model.PausedManualMotionActive;
            setEnable(controls, configurationUnlocked && ~isSelectedForMatrix);
        end

        function selectedParameters = zSweepSelectedBlockParameters(obj)
            selectedParameters = strings(1, 0);
            blockParameters = [ ...
                string(obj.Model.Ui.ZSweepBlockParam1DropDown.Value), ...
                string(obj.Model.Ui.ZSweepBlockParam2DropDown.Value)];
            for blockParameterIndex = 1:numel(blockParameters)
                if blockParameters(blockParameterIndex) ~= "None"
                    selectedParameters(end + 1) = ...
                        blockParameters(blockParameterIndex); %#ok<AGROW>
                end
            end
        end

        function plan = preparedTrajectoryPlan(obj, trajectory, sourceMode)
            if isfield(trajectory, 'writingPlan') && ...
                    istable(trajectory.writingPlan) && ...
                    any(string(trajectory.writingPlan.operation) == "path")
                kind = "path";
            else
                kind = "point";
            end

            if trajectoryHasPerPointTiming(trajectory)
                defaultDwellSeconds = obj.Model.Config.execution.pointExposureTime;
                defaultSettleSeconds = obj.Model.Config.execution.pointPause;
            else
                defaultDwellSeconds = positiveDurationMicroseconds( ...
                    obj.Model.Ui.PointExposureField.Value, ...
                    'Default point dwell');
                defaultSettleSeconds = nonnegativeScalar( ...
                    obj.Model.Ui.PointPauseField.Value, ...
                    'Default pre-write settle');
            end
            plan = struct( ...
                'kind', kind, ...
                'sourceMode', string(sourceMode), ...
                'sourceType', string(trajectory.sourceType), ...
                'trajectory', trajectory, ...
                'defaultDwellSeconds', defaultDwellSeconds, ...
                'defaultSettleSeconds', defaultSettleSeconds);
        end

        function markPreparedPlanDirty(obj, message)
            if isempty(obj.Model.PreparedPlan)
                return;
            end
            obj.Model.TrajectoryInputsDirty = true;
            obj.Model.RunCurrentText = string(message);
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
