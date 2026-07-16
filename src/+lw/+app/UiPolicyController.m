classdef UiPolicyController < handle
    %UIPOLICYCONTROLLER Apply transient GUI state and synchronization policy.

    properties (SetAccess = private)
        Model
        Ports
    end

    methods
        function obj = UiPolicyController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("UiPolicyController", ports, [ ...
                "carbide", "flir", "imaging", "isMakoConnected", "run", ...
                "stageLaser", "stageYToDisplay", "trajectory"]);
        end

        function syncAll(obj)
            obj.syncStatusLabels();
            obj.Ports.carbide.syncCarbideUi();
            obj.syncPositionFields();
            obj.Ports.trajectory.syncSourceModeUi();
            obj.Ports.trajectory.syncLevelingUi();
            obj.Ports.trajectory.syncTrajectoryPreview();
            obj.Ports.run.syncRunStatus();
            obj.Ports.flir.syncFlirUi();
            obj.Ports.imaging.syncImagingStatus();
            obj.Ports.imaging.syncBatchStatus();
            obj.Ports.run.syncRunParameterUi();
            obj.syncControlEnableStates();
        end

        function syncStatusLabels(obj)
            stagesConnected = obj.Ports.stageLaser.areStagesConnected();
            daqConnected = obj.Ports.stageLaser.areDAQConnected();
            carbideConnected = obj.Ports.carbide.areCarbideConnected();

            obj.Model.Ui.StageLamp.Color = lampColor(stagesConnected);
            obj.Model.Ui.DAQLamp.Color = lampColor(daqConnected);
            obj.Model.Ui.CarbideLamp.Color = lampColor(carbideConnected);
            if obj.Model.State.isPaused
                obj.Model.Ui.BusyLamp.Color = [0.25, 0.55, 0.95];
                busyText = ternary(obj.Model.PausedManualMotionActive, 'Paused Move', 'Paused');
            else
                obj.Model.Ui.BusyLamp.Color = lampColor(~obj.Model.State.isBusy, [0.2, 0.7, 0.2], [0.95, 0.7, 0.15]);
                busyText = ternary(obj.Model.State.isBusy, 'Busy', 'Idle');
            end
            obj.syncLaserIndicator();

            obj.Model.Ui.StageStatusLabel.Text = sprintf('Stages: %s', connectionText(stagesConnected));
            obj.Model.Ui.DAQStatusLabel.Text = sprintf('DAQ: %s', connectionText(daqConnected));
            obj.Model.Ui.CarbideStatusBarLabel.Text = sprintf('Carbide: %s', connectionText(carbideConnected));
            obj.Model.Ui.BusyStatusLabel.Text = busyText;
            obj.Ports.carbide.syncCarbideStateIndicator(carbideConnected);
            obj.Ports.carbide.syncCarbideShutterIndicator(carbideConnected);
            obj.Ports.carbide.syncCarbideStatusBarMetrics(carbideConnected);
            obj.syncCurrentXYZLabel();

            obj.Model.Ui.ConnectionStagesLabel.Text = sprintf('Stages: %s', connectionText(stagesConnected));
            obj.Model.Ui.ConnectionDAQLabel.Text = sprintf('DAQ: %s', connectionText(daqConnected));
            obj.Model.Ui.ConnectionCarbideLabel.Text = sprintf('Carbide: %s', connectionText(carbideConnected));
            obj.Model.Ui.ConnectionCarbideLabel.Tooltip = obj.Ports.carbide.carbideStatusTooltip();
            obj.Model.Ui.ConnectionBusyLabel.Text = sprintf('Busy: %s', ternary(obj.Model.State.isBusy, 'Yes', ternary(obj.Model.State.isPaused, busyText, 'No')));
            obj.Model.Ui.ConnectionStopLabel.Text = sprintf('Stop Flag: %s', ternary(obj.Model.State.stopRequested, 'True', 'False'));
        end

        function syncCurrentXYZLabel(obj)
            obj.Model.Ui.CurrentXYZLabel.Text = sprintf('X: %s, Y: %s, Z: %s', ...
                formatValue(obj.Model.State.currentPosition.x), ...
                formatValue(obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y)), ...
                formatValue(obj.Model.State.currentPosition.z));
        end

        function textValue = appendUnit(~, textValue, unitText)
            if strcmp(char(textValue), '-')
                return;
            end

            textValue = sprintf('%s %s', char(textValue), unitText);
        end

        function syncLaserIndicator(obj)
            isLaserOn = isfield(obj.Model.State, 'laserIsOn') && obj.Model.State.laserIsOn;
            obj.Model.Ui.StatusLaserStateLamp.Color = lampColor(isLaserOn);
            obj.Model.Ui.StatusLaserStateLabel.Text = sprintf('Laser State: %s', onOff(isLaserOn));
            obj.Model.Ui.LaserStateLamp.Color = lampColor(isLaserOn);
            obj.Model.Ui.LaserStateLabel.Text = sprintf('Laser %s', onOff(isLaserOn));
        end

        function syncPositionFields(~)
            % Compatibility hook: the original application intentionally did nothing here.
        end

        function syncControlEnableStates(obj)
            stagesConnected = obj.Ports.stageLaser.areStagesConnected();
            daqConnected = obj.Ports.stageLaser.areDAQConnected();
            flirConnected = obj.Ports.flir.isFlirConnected();
            makoConnected = obj.Ports.isMakoConnected();
            carbideConnected = obj.Ports.carbide.areCarbideConnected();
            carbideEnabled = obj.Ports.carbide.isCarbideEnabled();
            trajectoryLoaded = ~isempty(obj.Model.Trajectory);
            trajectoryReady = trajectoryLoaded && ~obj.Model.TrajectoryInputsDirty;
            isImported = obj.Ports.trajectory.selectedSourceMode() == "Imported Points";
            isZSweepMode = obj.Ports.run.selectedRunMode() == "Z Sweep Mode";
            isZSweepMatrixEnabled = isZSweepMode && obj.Model.Ui.ZSweepMatrixCheckBox.Value;
            isZSweepBlockEnabled = isZSweepMatrixEnabled && obj.Model.Ui.ZSweepBlockCheckBox.Value;
            isStreamMode = obj.Ports.run.selectedRunMode() == "Stream Mode";
            configurationUnlocked = ~obj.Model.State.isBusy && ~obj.Model.State.isPaused && ~obj.Model.PausedManualMotionActive;
            manualStageEnabled = stagesConnected && ~obj.Model.State.isBusy && ~obj.Model.PausedManualMotionActive;
            carbideWriteEnabled = carbideEnabled && carbideConnected && configurationUnlocked;
            flirDeviceAvailable = isfield(obj.Model.State, 'flir') && isfield(obj.Model.State.flir, 'devices') && ~isempty(obj.Model.State.flir.devices);

            setEnable([obj.Model.Ui.ImportedPointsRadio, obj.Model.Ui.MarkTextRadio, obj.Model.Ui.FrameRadio], ...
                configurationUnlocked && ~isZSweepMode);
            setEnable([obj.Model.Ui.PointModeRadio, obj.Model.Ui.StreamModeRadio, obj.Model.Ui.ZSweepModeRadio, obj.Model.Ui.CutPlanModeRadio], configurationUnlocked);
            setEnable({obj.Model.Ui.InputFileField, obj.Model.Ui.ColumnXField, obj.Model.Ui.ColumnYField, obj.Model.Ui.ColumnZField, ...
                obj.Model.Ui.ColumnPField, obj.Model.Ui.PlanPowerField, obj.Model.Ui.StartXField, obj.Model.Ui.StartYField, ...
                obj.Model.Ui.StartZField, obj.Model.Ui.MagnificationXField, obj.Model.Ui.MagnificationYField, ...
                obj.Model.Ui.MagnificationZField, obj.Model.Ui.EnableZCompensationCheckBox}, configurationUnlocked);

            setEnable(obj.Model.Ui.ConnectAllButton, configurationUnlocked && ...
                (~stagesConnected || ~daqConnected || (carbideEnabled && ~carbideConnected)));
            setEnable(obj.Model.Ui.ConnectStagesButton, ~stagesConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.ConnectDAQButton, ~daqConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.ConnectCarbideButton, carbideEnabled && ~carbideConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.DisconnectCarbideButton, carbideConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.DisconnectButton, ...
                (stagesConnected || daqConnected || carbideConnected || flirConnected || makoConnected) && ...
                configurationUnlocked);
            setEnable(obj.Model.Ui.FlirRefreshButton, ~flirConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.FlirDeviceDropDown, ~flirConnected && flirDeviceAvailable && configurationUnlocked);
            setEnable(obj.Model.Ui.FlirConnectButton, ~flirConnected && flirDeviceAvailable && configurationUnlocked);
            setEnable(obj.Model.Ui.FlirDisconnectButton, flirConnected && configurationUnlocked);
            setEnable([obj.Model.Ui.FlirExposureField, obj.Model.Ui.FlirApplyExposureButton, ...
                obj.Model.Ui.FlirGainField, obj.Model.Ui.FlirApplyGainButton, obj.Model.Ui.FlirTestCaptureButton], ...
                flirConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.OpenFlirLiveWindowButton, flirConnected && configurationUnlocked);
            obj.Ports.flir.syncFlirLiveWindowControlEnableStates();
            setEnable(obj.Model.Ui.HomeButton, stagesConnected && configurationUnlocked);
            setEnable([obj.Model.Ui.MoveButton, obj.Model.Ui.UseCurrentPositionButton], manualStageEnabled);
            for positionIndex = 1:numel(obj.Model.SavedStagePositions)
                saveButton = obj.Model.Ui.(sprintf('SavePosition%dButton', positionIndex));
                moveButton = obj.Model.Ui.(sprintf('MoveToPosition%dButton', positionIndex));
                setEnable(saveButton, manualStageEnabled);
                setEnable(moveButton, manualStageEnabled && ...
                    obj.Ports.stageLaser.hasSavedPosition(positionIndex));
            end
            setEnable(obj.Model.Ui.UseCurrentOriginButton, stagesConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.ZSweepUseCurrentButton, stagesConnected && configurationUnlocked && isZSweepMode);
            setEnable({obj.Model.Ui.PointExposureLabel, obj.Model.Ui.PointExposureField, obj.Model.Ui.PointPauseLabel, obj.Model.Ui.PointPauseField}, ...
                configurationUnlocked && obj.Ports.run.selectedRunMode() == "Point Mode");
            setEnable({obj.Model.Ui.StreamSpeedLabel, obj.Model.Ui.StreamSpeedField, obj.Model.Ui.TTLGateWidthLabel, obj.Model.Ui.TTLGateWidthField}, ...
                configurationUnlocked && isStreamMode);
            setEnable({obj.Model.Ui.ZSweepPowerLabel, obj.Model.Ui.ZSweepPowerField}, ...
                configurationUnlocked && isZSweepMode);
            setEnable({obj.Model.Ui.ZSweepDirectionLabel, obj.Model.Ui.ZSweepDirectionDropDown, ...
                obj.Model.Ui.ZSweepXLabel, obj.Model.Ui.ZSweepXField, obj.Model.Ui.ZSweepYLabel, obj.Model.Ui.ZSweepYField, ...
                obj.Model.Ui.ZSweepBackLabel, obj.Model.Ui.ZSweepBackField, obj.Model.Ui.ZSweepFrontLabel, obj.Model.Ui.ZSweepFrontField, ...
                obj.Model.Ui.ZSweepSpeedLabel, obj.Model.Ui.ZSweepSpeedField, obj.Model.Ui.ZSweepReturnSpeedLabel, ...
                obj.Model.Ui.ZSweepReturnSpeedField, obj.Model.Ui.ZSweepRepeatLabel, obj.Model.Ui.ZSweepRepeatField}, ...
                configurationUnlocked && isZSweepMode);
            setEnable(obj.Model.Ui.ZSweepMatrixCheckBox, configurationUnlocked && isZSweepMode);
            obj.Ports.run.updateZSweepMatrixParameterEnableStates(isZSweepMatrixEnabled);
            setEnable({obj.Model.Ui.ZSweepMatrixXParamDropDown, obj.Model.Ui.ZSweepMatrixYParamDropDown, ...
                obj.Model.Ui.ZSweepMatrixXValuesField, obj.Model.Ui.ZSweepMatrixYValuesField, ...
                obj.Model.Ui.ZSweepPitchXField, obj.Model.Ui.ZSweepPitchYField}, ...
                configurationUnlocked && isZSweepMatrixEnabled);
            setEnable(obj.Model.Ui.ZSweepBlockCheckBox, configurationUnlocked && isZSweepMatrixEnabled);
            setEnable({obj.Model.Ui.ZSweepBlockParam1DropDown, obj.Model.Ui.ZSweepBlockValues1Field, ...
                obj.Model.Ui.ZSweepBlockParam2DropDown, obj.Model.Ui.ZSweepBlockValues2Field, ...
                obj.Model.Ui.ZSweepBlockPitchXField, obj.Model.Ui.ZSweepBlockPitchYField}, ...
                configurationUnlocked && isZSweepBlockEnabled);
            setEnable([obj.Model.Ui.JogXMinusButton, obj.Model.Ui.JogXPlusButton, obj.Model.Ui.JogYMinusButton, ...
                obj.Model.Ui.JogYPlusButton, obj.Model.Ui.JogZMinusButton, obj.Model.Ui.JogZPlusButton], ...
                manualStageEnabled);
            setEnable([obj.Model.Ui.LaserOnButton, obj.Model.Ui.LaserOffButton, obj.Model.Ui.FireExposureButton], ...
                stagesConnected && daqConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.AutoStandbyAfterRunCheckBox, carbideEnabled && configurationUnlocked);
            setEnable(obj.Model.Ui.CarbideEnableOutputButton, carbideWriteEnabled);
            setEnable(obj.Model.Ui.CarbideStandbyButton, carbideWriteEnabled);
            setEnable(obj.Model.Ui.CarbideCloseOutputButton, carbideEnabled && carbideConnected);
            setEnable({obj.Model.Ui.CarbidePpDividerField, obj.Model.Ui.CarbideApplyPpButton, ...
                obj.Model.Ui.CarbidePresetDropDown, obj.Model.Ui.CarbideApplyPresetButton}, carbideWriteEnabled);
            setEnable(obj.Model.Ui.BrowseInputFileButton, isImported && configurationUnlocked);
            setEnable(obj.Model.Ui.ImportGenerateButton, configurationUnlocked);
            setEnable([obj.Model.Ui.Mark0Button, obj.Model.Ui.Mark1Button, obj.Model.Ui.Mark2Button], stagesConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.GoToFirstPointButton, trajectoryReady && stagesConnected && configurationUnlocked && ~isZSweepMode);
            setEnable(obj.Model.Ui.CheckBoundsButton, trajectoryReady && configurationUnlocked && ~isZSweepMode);
            setEnable(obj.Model.Ui.StartRunButton, ((trajectoryReady && ~isZSweepMode) || isZSweepMode) && ...
                stagesConnected && daqConnected && configurationUnlocked);
            setEnable([obj.Model.Ui.ImagingXField, obj.Model.Ui.ImagingYField, obj.Model.Ui.ImagingZStartField, obj.Model.Ui.ImagingZEndField, ...
                obj.Model.Ui.ImagingZStepField, obj.Model.Ui.ImagingSettleField, obj.Model.Ui.ImagingTimeoutField, obj.Model.Ui.ImagingPrefixField, ...
                obj.Model.Ui.ImagingFolderField, obj.Model.Ui.ImagingBrowseFolderButton, obj.Model.Ui.ImagingAutoExposureCheckBox], configurationUnlocked);
            setEnable([obj.Model.Ui.ImagingAutoExposureSamplesField, obj.Model.Ui.ImagingAutoExposureSafetyFactorField], configurationUnlocked && ...
                logical(obj.Model.Ui.ImagingAutoExposureCheckBox.Value));
            setEnable([obj.Model.Ui.ImagingSetEndButton, obj.Model.Ui.ImagingSetStartButton], stagesConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.Start3DImagingButton, stagesConnected && flirConnected && configurationUnlocked);
            setEnable(obj.Model.Ui.Stop3DImagingButton, obj.Model.ImagingRunActive && obj.Model.State.isBusy);
            setEnable({obj.Model.Ui.BatchNameField, obj.Model.Ui.BatchSlmTable, obj.Model.Ui.BatchAddRowButton, ...
                obj.Model.Ui.BatchDuplicateRowButton, obj.Model.Ui.BatchDeleteRowButton, obj.Model.Ui.BatchMoveUpButton, ...
                obj.Model.Ui.BatchMoveDownButton, obj.Model.Ui.BatchImportButton, obj.Model.Ui.BatchExportButton, ...
                obj.Model.Ui.BatchValidateButton, obj.Model.Ui.BatchSweepBaseNameField, obj.Model.Ui.BatchSweepParamADropDown, ...
                obj.Model.Ui.BatchSweepValuesAField, obj.Model.Ui.BatchSweepParamBDropDown, obj.Model.Ui.BatchSweepValuesBField, ...
                obj.Model.Ui.BatchGenerateSweepButton}, configurationUnlocked);
            setEnable(obj.Model.Ui.BatchConnectSlmButton, configurationUnlocked && ~obj.Ports.imaging.isBatchSlmConnected());
            setEnable(obj.Model.Ui.BatchDisconnectSlmButton, configurationUnlocked && obj.Ports.imaging.isBatchSlmConnected());
            setEnable(obj.Model.Ui.BatchPreviewSelectedButton, configurationUnlocked);
            setEnable(obj.Model.Ui.BatchShowSelectedButton, configurationUnlocked && obj.Ports.imaging.isBatchSlmConnected());
            setEnable(obj.Model.Ui.StartBatchImagingButton, stagesConnected && flirConnected && ...
                obj.Ports.imaging.isBatchSlmConnected() && configurationUnlocked);
            setEnable(obj.Model.Ui.StopBatchImagingButton, obj.Model.ImagingRunActive && obj.Model.State.isBusy);
            obj.Ports.run.syncPauseResumeButton(isStreamMode);
            setEnable(obj.Model.Ui.StopRunButton, obj.Model.State.isBusy || obj.Model.State.isPaused);
            setEnable(obj.Model.Ui.GlobalStopButton, true);
        end

        function syncPausedUiLight(obj)
            obj.syncStatusLabels();
            obj.syncPositionFields();
            obj.Ports.run.syncRunStatus();
            obj.syncControlEnableStates();
            obj.Ports.trajectory.syncPreviewCurrentPosition();
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function apply3DPreviewLimits(obj)
            xValues = obj.Model.PreviewBounds.x(:);
            yValues = obj.Model.PreviewBounds.y(:);
            zValues = obj.Model.PreviewBounds.z(:);

            if isfinite(obj.Model.State.currentPosition.x) && isfinite(obj.Model.State.currentPosition.y) && isfinite(obj.Model.State.currentPosition.z)
                xValues(end + 1, 1) = obj.Model.State.currentPosition.x;
                yValues(end + 1, 1) = obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y);
                zValues(end + 1, 1) = obj.Model.State.currentPosition.z;
            end

            if isempty(xValues)
                obj.Model.Ui.TrajectoryAxes.DataAspectRatio = [1, 1, 1];
                obj.Model.Ui.TrajectoryAxes.DataAspectRatioMode = 'manual';
                view(obj.Model.Ui.TrajectoryAxes, 30, 25);
                return;
            end

            xMin = min(xValues);
            xMax = max(xValues);
            yMin = min(yValues);
            yMax = max(yValues);
            zMin = min(zValues);
            zMax = max(zValues);

            xCenter = (xMin + xMax) / 2;
            yCenter = (yMin + yMax) / 2;
            zCenter = (zMin + zMax) / 2;

            span = max([xMax - xMin, yMax - yMin, zMax - zMin]);
            span = max(span, 0.01);
            margin = max(0.05 * span, 0.002);
            halfRange = span / 2 + margin;

            obj.Model.Ui.TrajectoryAxes.XLim = [xCenter - halfRange, xCenter + halfRange];
            obj.Model.Ui.TrajectoryAxes.YLim = [yCenter - halfRange, yCenter + halfRange];
            obj.Model.Ui.TrajectoryAxes.ZLim = [zCenter - halfRange, zCenter + halfRange];
            obj.Model.Ui.TrajectoryAxes.DataAspectRatio = [1, 1, 1];
            obj.Model.Ui.TrajectoryAxes.DataAspectRatioMode = 'manual';
            view(obj.Model.Ui.TrajectoryAxes, 30, 25);
        end

        function clearPreviewColorbar(obj)
            if ~isempty(obj.Model.Ui.PreviewColorbar) && isgraphics(obj.Model.Ui.PreviewColorbar)
                delete(obj.Model.Ui.PreviewColorbar);
            end
            obj.Model.Ui.PreviewColorbar = [];
        end

    end
end
