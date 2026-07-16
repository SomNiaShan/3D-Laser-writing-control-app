classdef StageLaserController < handle
    %STAGELASERCONTROLLER Own stages, DAQ, manual motion, laser, and exposure safety.

    properties (SetAccess = private)
        Model
        Ports
    end

    methods
        function obj = StageLaserController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("StageLaserController", ports, [ ...
                "displayYToStage", "flirLive", "logMessage", "runUiAction", "stageYToDisplay", ...
                "syncAll", "syncCurrentXYZLabel", "syncLaserIndicator", "syncPausedUiLight", ...
                "syncPreviewCurrentPosition", "syncRunStatus", "validateTargetForUi"]);
        end

        function onConnectStages(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.connectStagesImpl(), 'Failed to connect stages');
        end

        function connectStagesImpl(obj)
            obj.Model.State = obj.Model.Services.stage.connect(obj.Model.State, obj.Model.Config);
            obj.Ports.logMessage(sprintf('Stages connected on %s.', obj.Model.Config.stage.comPort));
            obj.tryRefreshPosition(false);
            obj.startPositionTimer();
            obj.copyCurrentPositionToAbsoluteTarget();
            obj.Ports.logMessage('Absolute move target set to current stage position.');
            obj.logStageDefaultMotionSettings();
        end

        function onConnectDAQ(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.connectDAQImpl(), 'Failed to connect DAQ');
        end

        function connectDAQImpl(obj)
            obj.Model.State = obj.Model.Services.daq.connect(obj.Model.State, obj.Model.Config);
            obj.Ports.logMessage(sprintf('DAQ connected on %s %s.', obj.Model.Config.daq.device, obj.Model.Config.daq.powerChannel));
        end

        function onHomeStages(obj, ~, ~)
            choice = string(obj.Model.Services.dialog.confirm(obj.Model.Figure, ...
                'Home will move all connected stages to their reference positions. Continue?', ...
                'Confirm Home', ...
                'Options', {'Home', 'Cancel'}, ...
                'DefaultOption', 'Cancel', ...
                'CancelOption', 'Cancel', ...
                'Icon', 'warning'));
            if choice ~= "Home"
                obj.Ports.logMessage('Home cancelled.');
                return;
            end
            obj.Ports.runUiAction(@() obj.homeImpl(), 'Failed while homing stages');
        end

        function homeImpl(obj)
            obj.requireStagesConnected();
            obj.Model.State = obj.Model.Services.stage.home(obj.Model.State);
            obj.Ports.logMessage('Stages homed.');
        end

        function tryRefreshPosition(obj, shouldLog)
            obj.requireStagesConnected();
            obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
            obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
            if shouldLog
                obj.Ports.logMessage(sprintf('Position refreshed: X %.3f, Y %.3f, Z %.3f mm.', ...
                    obj.Model.State.currentPosition.x, obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), obj.Model.State.currentPosition.z));
            end
        end

        function startPositionTimer(obj)
            if ~obj.areStagesConnected()
                return;
            end

            obj.stopPositionTimer();
            obj.Model.Ui.PositionPollFailureCount = 0;
            obj.Model.Ui.PositionTimerHandle = obj.Model.Services.timer.create( ...
                'Name', 'LaserWritingPositionRefresh', ...
                'ExecutionMode', 'fixedSpacing', ...
                'BusyMode', 'drop', ...
                'Period', obj.Model.Ui.PositionTimerPeriodSeconds, ...
                'TimerFcn', @obj.onPositionTimer);
            start(obj.Model.Ui.PositionTimerHandle);
        end

        function stopPositionTimer(obj)
            try
                if isfield(obj.Model.Ui, 'PositionTimerHandle') && ~isempty(obj.Model.Ui.PositionTimerHandle) && ...
                        isvalid(obj.Model.Ui.PositionTimerHandle)
                    stop(obj.Model.Ui.PositionTimerHandle);
                    delete(obj.Model.Ui.PositionTimerHandle);
                end
            catch
            end
            obj.Model.Ui.PositionTimerHandle = [];
            obj.Model.Ui.PositionPollInProgress = false;
        end

        function onPositionTimer(obj, ~, ~)
            try
                if ~isvalid(obj.Model.Figure)
                    obj.stopPositionTimer();
                    return;
                end
            catch
                obj.stopPositionTimer();
                return;
            end

            if ~obj.areStagesConnected()
                obj.stopPositionTimer();
                return;
            end

            obj.refreshLivePosition(false);
        end

        function refreshLivePosition(obj, shouldLog)
            if nargin < 2
                shouldLog = false;
            end
            if ~obj.areStagesConnected() || obj.Model.Ui.PositionPollInProgress
                return;
            end

            obj.Model.Ui.PositionPollInProgress = true;
            cleanupObj = onCleanup(@() obj.setPositionPollInProgress(false));
            try
                obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
                obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
                obj.Model.Ui.PositionPollFailureCount = 0;
                if shouldLog
                    obj.Ports.logMessage(sprintf('Position refreshed: X %.3f, Y %.3f, Z %.3f mm.', ...
                        obj.Model.State.currentPosition.x, obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), obj.Model.State.currentPosition.z));
                end
                obj.Ports.syncCurrentXYZLabel();
                obj.Ports.syncPreviewCurrentPosition();
                obj.Model.Services.ui.drawnow('limitrate');
            catch ME
                obj.Model.Ui.PositionPollFailureCount = obj.Model.Ui.PositionPollFailureCount + 1;
                if obj.Model.Ui.PositionPollFailureCount == 1
                    obj.Ports.logMessage(sprintf('Position refresh failed: %s', compactErrorMessage(ME)));
                end
                if obj.Model.Ui.PositionPollFailureCount >= 3
                    obj.stopPositionTimer();
                    obj.Ports.logMessage('Live position refresh stopped after repeated failures.');
                end
            end
            clear cleanupObj
        end

        function refreshLivePositionIfDue(obj)
            if obj.Model.Services.clock.toc(obj.Model.LastPositionRefreshTic) < ...
                    obj.Model.Ui.PositionTimerPeriodSeconds
                return;
            end
            obj.refreshLivePosition(false);
        end

        function yieldWithLivePosition(obj)
            obj.Model.Services.ui.drawnow();
            obj.refreshLivePositionIfDue();
        end

        function yieldWithLivePositionAndFlirLive(obj)
            obj.yieldWithLivePosition();
            obj.pumpFlirLiveDuringManualMove();
        end

        function pumpFlirLiveDuringManualMove(obj)
            if ~obj.Model.Ui.FlirLiveEnabled || obj.Model.Ui.FlirLiveTickInProgress
                return;
            end
            if obj.Model.Services.clock.toc(obj.Model.Ui.FlirLiveLastFrameTic) < ...
                    obj.Model.Ui.FlirLivePeriodSeconds
                return;
            end

            obj.Model.Ui.FlirLiveLastFrameTic = obj.Model.Services.clock.tic();
            obj.Ports.flirLive('tick', true);
        end

        function setPositionPollInProgress(obj, value)
            obj.Model.Ui.PositionPollInProgress = logical(value);
        end

        function onUseCurrentPosition(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.useCurrentPositionImpl(), 'Failed to copy current position');
        end

        function useCurrentPositionImpl(obj)
            obj.requireStagesConnected();
            obj.ensureCurrentPosition();
            obj.copyCurrentPositionToAbsoluteTarget();
            obj.Model.Ui.StartXField.Value = obj.Model.State.currentPosition.x;
            obj.Model.Ui.StartYField.Value = obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y);
            obj.Model.Ui.StartZField.Value = obj.Model.State.currentPosition.z;
            obj.Ports.logMessage('Current position copied into target and origin fields.');
        end

        function copyCurrentPositionToAbsoluteTarget(obj, position)
            if nargin < 2
                position = obj.Model.State.currentPosition;
            end
            obj.Model.Ui.TargetXField.Value = position.x;
            obj.Model.Ui.TargetYField.Value = obj.Ports.stageYToDisplay(position.y);
            obj.Model.Ui.TargetZField.Value = position.z;
        end

        function onSavePosition(obj, positionIndex)
            positionIndex = obj.validatePositionIndex(positionIndex);
            if obj.hasSavedPosition(positionIndex)
                position = obj.Model.SavedStagePositions(positionIndex);
                choice = string(obj.Model.Services.dialog.confirm(obj.Model.Figure, ...
                    sprintf(['Update saved position %d?\n\n' ...
                             'Existing position: X %.3f, Y %.3f, Z %.3f mm\n\n' ...
                             'This will overwrite it with the current stage position.'], ...
                        positionIndex, position.x, obj.Ports.stageYToDisplay(position.y), position.z), ...
                    'Confirm Position Update', ...
                    'Options', {'Update', 'Cancel'}, ...
                    'DefaultOption', 'Cancel', ...
                    'CancelOption', 'Cancel', ...
                    'Icon', 'warning'));
                if choice ~= "Update"
                    return;
                end
            end

            obj.Ports.runUiAction(@() obj.savePositionImpl(positionIndex), ...
                sprintf('Failed to save position %d', positionIndex));
        end

        function savePositionImpl(obj, positionIndex)
            positionIndex = obj.validatePositionIndex(positionIndex);
            obj.requireStagesConnected();
            obj.ensureCurrentPosition();

            position = obj.Model.State.currentPosition;
            obj.Model.SavedStagePositions(positionIndex) = struct( ...
                'isSet', true, 'x', position.x, 'y', position.y, 'z', position.z);
            obj.syncSavedPositionButton(positionIndex);
            obj.Ports.logMessage(sprintf('Saved position %d: X %.3f, Y %.3f, Z %.3f mm.', ...
                positionIndex, position.x, obj.Ports.stageYToDisplay(position.y), position.z));
        end

        function onMoveToPosition(obj, positionIndex)
            obj.Ports.runUiAction(@() obj.moveToPositionImpl(positionIndex), ...
                sprintf('Failed to move to saved position %d', positionIndex));
        end

        function moveToPositionImpl(obj, positionIndex)
            positionIndex = obj.validatePositionIndex(positionIndex);
            if ~obj.hasSavedPosition(positionIndex)
                error('Position %d has not been saved yet.', positionIndex);
            end

            position = obj.Model.SavedStagePositions(positionIndex);
            obj.copyCurrentPositionToAbsoluteTarget(position);
            obj.moveAbsoluteImpl();
        end

        function tf = hasSavedPosition(obj, positionIndex)
            positionIndex = obj.validatePositionIndex(positionIndex);
            position = obj.Model.SavedStagePositions(positionIndex);
            tf = position.isSet && all(isfinite([position.x, position.y, position.z]));
        end

        function syncSavedPositionButton(obj, positionIndex)
            positionIndex = obj.validatePositionIndex(positionIndex);
            position = obj.Model.SavedStagePositions(positionIndex);
            saveButton = obj.Model.Ui.(sprintf('SavePosition%dButton', positionIndex));
            moveButton = obj.Model.Ui.(sprintf('MoveToPosition%dButton', positionIndex));
            saveButton.Text = sprintf('Update %d', positionIndex);
            tooltipText = sprintf('Position %d: X %.3f, Y %.3f, Z %.3f mm', ...
                positionIndex, position.x, obj.Ports.stageYToDisplay(position.y), position.z);
            saveButton.Tooltip = sprintf('Overwrite %s with the current stage position', tooltipText);
            moveButton.Tooltip = sprintf('Move to %s', tooltipText);
        end

        function positionIndex = validatePositionIndex(obj, positionIndex)
            positionIndex = positiveInteger(positionIndex, 'Saved position slot');
            if positionIndex > numel(obj.Model.SavedStagePositions)
                error('Saved position slot must be between 1 and %d.', ...
                    numel(obj.Model.SavedStagePositions));
            end
        end

        function onUseCurrentZSweepPosition(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.useCurrentZSweepPositionImpl(), 'Failed to copy current position into Z Sweep');
        end

        function useCurrentZSweepPositionImpl(obj)
            obj.requireStagesConnected();
            obj.ensureCurrentPosition();
            obj.Model.Ui.ZSweepXField.Value = obj.Model.State.currentPosition.x;
            obj.Model.Ui.ZSweepYField.Value = obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y);
            obj.Model.Ui.ZSweepBackField.Value = obj.Model.State.currentPosition.z;
            obj.Model.Ui.ZSweepFrontField.Value = obj.Model.State.currentPosition.z;
            obj.Ports.logMessage(sprintf('Current position copied into Z Sweep: X %.3f, Y %.3f, Z %.3f mm.', ...
                obj.Model.State.currentPosition.x, obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), obj.Model.State.currentPosition.z));
        end

        function onMoveAbsolute(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.moveAbsoluteImpl(), 'Failed during absolute move');
        end

        function moveAbsoluteImpl(obj)
            obj.requireStagesConnected();
            target = obj.readAbsoluteTarget();
            obj.Ports.validateTargetForUi(target, 'Absolute move');
            obj.Model.State.stopRequested = false;
            pausedManualMove = obj.beginPausedManualStageOperation();
            cleanupObj = onCleanup(@() obj.finishPausedManualStageOperation(pausedManualMove));
            [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                obj.Model.State, target, obj.readAbsoluteMotion(), obj.manualMoveOptions());
            if wasStopped
                obj.Ports.logMessage('Absolute move stopped before reaching target.');
                return;
            end
            obj.Ports.logMessage(sprintf('Moved to X %.3f, Y %.3f, Z %.3f mm.', ...
                target.x, obj.Ports.stageYToDisplay(target.y), target.z));
        end

        function onJog(obj, axisName, direction)
            obj.Ports.runUiAction(@() obj.jogImpl(axisName, direction), sprintf('Failed during %s jog', upper(axisName)));
        end

        function jogImpl(obj, axisName, direction)
            obj.requireStagesConnected();
            obj.ensureCurrentPosition();
            target = obj.Model.State.currentPosition;
            stepValue = obj.readManualStep(axisName);
            if axisName == 'y'
                target.y = target.y - direction * stepValue;
            else
                target.(axisName) = target.(axisName) + direction * stepValue;
            end
            obj.Ports.validateTargetForUi(target, sprintf('%s jog', upper(axisName)));
            obj.Model.State.stopRequested = false;
            pausedManualMove = obj.beginPausedManualStageOperation();
            cleanupObj = onCleanup(@() obj.finishPausedManualStageOperation(pausedManualMove));
            [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                obj.Model.State, target, obj.readManualMotion(), obj.manualMoveOptions());
            if wasStopped
                obj.Ports.logMessage(sprintf('%s jog stopped before reaching target.', upper(axisName)));
            end
        end

        function didBegin = beginPausedManualStageOperation(obj)
            didBegin = obj.Model.State.isPaused && ~obj.Model.State.isBusy && ~obj.Model.PausedManualMotionActive;
            if ~didBegin
                return;
            end

            obj.Model.PausedManualMotionActive = true;
            obj.Ports.syncPausedUiLight();
        end

        function finishPausedManualStageOperation(obj, didBegin)
            if ~didBegin
                return;
            end

            obj.Model.PausedManualMotionActive = false;
            try
                if obj.areStagesConnected()
                    obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
                    obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
                end
            catch
            end
            if obj.Model.State.isPaused
                obj.Ports.syncPausedUiLight();
            else
                obj.Ports.syncAll();
            end
        end

        function options = manualMoveOptions(obj)
            options = struct( ...
                'shouldStopFcn', @obj.isStopRequested, ...
                'yieldFcn', @obj.yieldWithLivePositionAndFlirLive, ...
                'pollIntervalSeconds', 0.02);
        end

        function onLaserOn(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.laserOnImpl(), 'Failed to turn laser on');
        end

        function laserOnImpl(obj)
            obj.requireLaserReady();
            powerPercent = obj.Model.Ui.LaserPowerField.Value;
            obj.Model.Services.laser.setPower(obj.Model.State, powerPercent);
            obj.Model.Services.stage.setPulseTrigger(obj.Model.State, true, obj.Model.Config);
            obj.setLaserState(true);
        end

        function onLaserOff(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.laserOffImpl(), 'Failed to turn laser off');
        end

        function laserOffImpl(obj)
            obj.forceLaserSafeOff();
        end

        function onFireExposure(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused
                return;
            end
            obj.Ports.runUiAction(@() obj.fireExposureImpl(), 'Failed during manual exposure');
        end

        function fireExposureImpl(obj)
            obj.requireLaserReady();
            exposureSeconds = positiveDurationMicroseconds(obj.Model.Ui.ExposureTimeField.Value, 'Exposure time');
            repeatCount = positiveInteger(obj.Model.Ui.ExposureRepeatField.Value, 'Repeat count');
            intervalSeconds = nonnegativeScalar(obj.Model.Ui.ExposureIntervalField.Value, 'Interval');
            powerPercent = obj.Model.Ui.PreviewPowerField.Value;

            obj.Model.State.stopRequested = false;
            obj.Model.State.isBusy = true;
            obj.Model.RunProgressText = sprintf('0 / %d', repeatCount);
            obj.Model.RunCurrentText = "Manual exposure";
            obj.Ports.logMessage(sprintf('Manual exposure started: %d repeats.', repeatCount));
            obj.Ports.syncAll();

            try
                for k = 1:repeatCount
                    obj.yieldWithLivePosition();
                    if obj.Model.State.stopRequested
                        break;
                    end

                    wasStopped = obj.Model.Services.laser.manualExposure( ...
                        obj.Model.State, obj.Model.Config, powerPercent, exposureSeconds, ...
                        @obj.setLaserState, @obj.isStopRequested, @obj.yieldWithLivePosition);
                    if wasStopped
                        break;
                    end
                    obj.Model.RunProgressText = sprintf('%d / %d', k, repeatCount);
                    obj.Model.RunCurrentText = sprintf('Exposure %d', k);
                    obj.Ports.syncRunStatus();

                    if k < repeatCount
                        obj.pauseWithUi(intervalSeconds);
                    end
                end

                if obj.Model.State.stopRequested
                    obj.Ports.logMessage('Manual exposure stopped by user.');
                else
                    obj.Ports.logMessage('Manual exposure finished.');
                end
            catch ME
                obj.finishManualBusy();
                rethrow(ME);
            end

            obj.finishManualBusy();
        end

        function finishManualBusy(obj)
            obj.forceLaserSafeOff();
            obj.Model.State.isBusy = false;
            if obj.Model.State.stopRequested
                obj.Model.RunCurrentText = "Stopped";
            else
                obj.Model.RunCurrentText = "Idle";
            end
            obj.Ports.syncAll();
        end

        function configureMotionNumberFormats(obj)
            targetFields = [obj.Model.Ui.TargetXField, obj.Model.Ui.TargetYField, obj.Model.Ui.TargetZField, ...
                obj.Model.Ui.ImagingXField, obj.Model.Ui.ImagingYField, obj.Model.Ui.ImagingZStartField, obj.Model.Ui.ImagingZEndField, ...
                obj.Model.Ui.ImagingZStepField];
            velocityFields = [ ...
                obj.Model.Ui.ManualVelXField, obj.Model.Ui.ManualVelYField, obj.Model.Ui.ManualVelZField, ...
                obj.Model.Ui.AbsoluteVelXField, obj.Model.Ui.AbsoluteVelYField, obj.Model.Ui.AbsoluteVelZField, ...
                obj.Model.Ui.StreamSpeedField, obj.Model.Ui.ZSweepSpeedField, obj.Model.Ui.ZSweepReturnSpeedField];
            accelerationFields = [ ...
                obj.Model.Ui.ManualAccXField, obj.Model.Ui.ManualAccYField, obj.Model.Ui.ManualAccZField, ...
                obj.Model.Ui.AbsoluteAccXField, obj.Model.Ui.AbsoluteAccYField, obj.Model.Ui.AbsoluteAccZField];

            for fieldIndex = 1:numel(targetFields)
                targetFields(fieldIndex).ValueDisplayFormat = '%.3f';
            end
            for fieldIndex = 1:numel(velocityFields)
                velocityFields(fieldIndex).ValueDisplayFormat = '%.3f';
            end
            for fieldIndex = 1:numel(accelerationFields)
                accelerationFields(fieldIndex).ValueDisplayFormat = '%.0f';
            end
        end

        function ensureCurrentPosition(obj)
            obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
            obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
        end

        function setLaserState(obj, isOn)
            obj.Model.State.laserIsOn = logical(isOn);
            obj.Ports.syncLaserIndicator();
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function tf = isStopRequested(obj)
            tf = obj.Model.State.stopRequested;
        end

        function tf = isPauseRequested(obj)
            tf = obj.Model.State.pauseRequested;
        end

        function requireStagesConnected(obj)
            if ~obj.areStagesConnected()
                error('Stages are not connected.');
            end
        end

        function requireDAQConnected(obj)
            if ~obj.areDAQConnected()
                error('DAQ is not connected.');
            end
        end

        function requireLaserReady(obj)
            obj.requireStagesConnected();
            obj.requireDAQConnected();
        end

        function tf = areStagesConnected(obj)
            tf = isfield(obj.Model.State, 'axes') && ~isempty(obj.Model.State.axes) && ...
                isfield(obj.Model.State.axes, 'x') && ~isempty(obj.Model.State.axes.x) && ...
                isfield(obj.Model.State.axes, 'y') && ~isempty(obj.Model.State.axes.y) && ...
                isfield(obj.Model.State.axes, 'z') && ~isempty(obj.Model.State.axes.z);
        end

        function tf = areDAQConnected(obj)
            tf = isfield(obj.Model.State, 'daq') && ~isempty(obj.Model.State.daq);
        end

        function logStageDefaultMotionSettings(obj)
            if ~obj.areStagesConnected()
                return;
            end

            axisNames = {'x', 'y', 'z'};
            summaryParts = cell(1, numel(axisNames));
            warningParts = {};

            for axisIndex = 1:numel(axisNames)
                axisName = axisNames{axisIndex};
                axisLabel = upper(axisName);
                try
                    axisSettings = obj.Model.State.axes.(axisName).getSettings();
                    maxSpeed = axisSettings.get( ...
                        'maxspeed', zaber.motion.Units.VELOCITY_MILLIMETRES_PER_SECOND);
                    acceleration = axisSettings.get( ...
                        'accel', zaber.motion.Units.ACCELERATION_MILLIMETRES_PER_SECOND_SQUARED);
                    summaryParts{axisIndex} = sprintf('%s default speed %.3f mm/s, default acceleration %.3f mm/s^2', ...
                        axisLabel, maxSpeed, acceleration);
                catch ME
                    summaryParts{axisIndex} = sprintf('%s unavailable', axisLabel);
                    warningParts{end + 1} = sprintf('%s: %s', axisLabel, ME.message); %#ok<AGROW>
                end
            end

            obj.Ports.logMessage(sprintf('Stage default motion settings: %s.', strjoin(summaryParts, ' | ')));
            if ~isempty(warningParts)
                obj.Ports.logMessage(sprintf('Stage default motion settings query warning: %s.', strjoin(warningParts, ' | ')));
            end
        end

        function motion = readManualMotion(obj)
            motion = struct();
            motion.velocity = struct( ...
                'x', nonnegativeScalar(obj.Model.Ui.ManualVelXField.Value, 'Manual X velocity'), ...
                'y', nonnegativeScalar(obj.Model.Ui.ManualVelYField.Value, 'Manual Y velocity'), ...
                'z', nonnegativeScalar(obj.Model.Ui.ManualVelZField.Value, 'Manual Z velocity'));
            motion.acceleration = struct( ...
                'x', nonnegativeScalar(obj.Model.Ui.ManualAccXField.Value, 'Manual X acceleration'), ...
                'y', nonnegativeScalar(obj.Model.Ui.ManualAccYField.Value, 'Manual Y acceleration'), ...
                'z', nonnegativeScalar(obj.Model.Ui.ManualAccZField.Value, 'Manual Z acceleration'));
        end

        function motion = readAbsoluteMotion(obj)
            motion = struct();
            motion.velocity = struct( ...
                'x', nonnegativeScalar(obj.Model.Ui.AbsoluteVelXField.Value, 'Absolute X velocity'), ...
                'y', nonnegativeScalar(obj.Model.Ui.AbsoluteVelYField.Value, 'Absolute Y velocity'), ...
                'z', nonnegativeScalar(obj.Model.Ui.AbsoluteVelZField.Value, 'Absolute Z velocity'));
            motion.acceleration = struct( ...
                'x', nonnegativeScalar(obj.Model.Ui.AbsoluteAccXField.Value, 'Absolute X acceleration'), ...
                'y', nonnegativeScalar(obj.Model.Ui.AbsoluteAccYField.Value, 'Absolute Y acceleration'), ...
                'z', nonnegativeScalar(obj.Model.Ui.AbsoluteAccZField.Value, 'Absolute Z acceleration'));
        end

        function target = readAbsoluteTarget(obj)
            target = struct( ...
                'x', obj.Model.Ui.TargetXField.Value, ...
                'y', obj.Ports.displayYToStage(obj.Model.Ui.TargetYField.Value), ...
                'z', obj.Model.Ui.TargetZField.Value);
        end

        function stepValue = readManualStep(obj, axisName)
            switch axisName
                case 'x'
                    stepValue = positiveScalar(obj.Model.Ui.ManualStepXField.Value, 'Manual X step');
                case 'y'
                    stepValue = positiveScalar(obj.Model.Ui.ManualStepYField.Value, 'Manual Y step');
                otherwise
                    stepValue = positiveScalar(obj.Model.Ui.ManualStepZField.Value, 'Manual Z step');
            end
        end

        function forceLaserSafeOff(obj)
            obj.Model.State.laserIsOn = false;
            try
                if obj.areStagesConnected()
                    obj.Model.Services.stage.setPulseTrigger(obj.Model.State, false, obj.Model.Config);
                end
            catch
            end
            try
                if obj.areDAQConnected()
                    obj.Model.Services.daq.write(obj.Model.State.daq, 0);
                end
            catch
            end
        end

        function requestStageStop(obj)
            try
                if obj.areStagesConnected()
                    obj.Model.Services.stage.stop(obj.Model.State);
                end
            catch
            end
        end

        function pauseWithUi(obj, seconds)
            if seconds <= 0
                return;
            end

            timerStart = obj.Model.Services.clock.tic();
            while obj.Model.Services.clock.toc(timerStart) < seconds
                obj.yieldWithLivePosition();
                if obj.Model.State.stopRequested
                    break;
                end
                obj.Model.Services.clock.pause(0.02);
            end
        end

    end
end
