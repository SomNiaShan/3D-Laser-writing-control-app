classdef AppController < handle
    %APPCONTROLLER Compose controllers, build the GUI, and own app lifetime.

    properties (SetAccess = private)
        Model
        Figure
        Carbide
        Flir
        StageLaser
        Trajectory
        Run
        Imaging
        UiPolicy
        Safety
    end

    methods
        function obj = AppController(projectRoot, serviceOverrides)
            arguments
                projectRoot (1, 1) string
                serviceOverrides (1, 1) struct = struct()
            end

            if ~isfolder(projectRoot)
                error('Project folder not found: %s', projectRoot);
            end

            obj.Model = lw.app.Model(lw_hardware_config(), lw_default_state(), ...
                lw.app.defaultServices(serviceOverrides));
            obj.Carbide = lw.app.CarbideController(obj.Model, obj.carbidePorts());
            obj.Flir = lw.app.FlirController(obj.Model, obj.flirPorts());
            obj.StageLaser = lw.app.StageLaserController(obj.Model, obj.stageLaserPorts());
            obj.Trajectory = lw.app.TrajectoryController(obj.Model, obj.trajectoryPorts());
            obj.Run = lw.app.RunController(obj.Model, obj.runPorts(projectRoot));
            obj.Imaging = lw.app.ImagingController(obj.Model, obj.imagingPorts());
            obj.UiPolicy = lw.app.UiPolicyController(obj.Model, obj.uiPolicyPorts());
            obj.Safety = lw.app.SafetyCoordinator(obj.Model, obj.safetyPorts());
            obj.buildUi();
            obj.resetFieldsFromConfig();
            obj.Trajectory.initializeSourceModeMemory();
            obj.logMessage('App ready.');
            obj.UiPolicy.syncAll();
            obj.Figure = obj.Model.Figure;
            setappdata(obj.Model.Figure, 'LaserWritingAppController', obj);
        end
    end

    methods (Access = private)
        function ports = carbidePorts(obj)
            ports = struct( ...
                'appendUnit', @(varargin) obj.UiPolicy.appendUnit(varargin{:}), ...
                'logMessage', @obj.logMessage, ...
                'reportError', @obj.reportError, ...
                'runUiAction', @obj.runUiAction, ...
                'syncAll', @() obj.UiPolicy.syncAll(), ...
                'syncControlEnableStates', @() obj.UiPolicy.syncControlEnableStates(), ...
                'syncStatusLabels', @() obj.UiPolicy.syncStatusLabels());
        end

        function ports = flirPorts(obj)
            ports = struct( ...
                'logMessage', @obj.logMessage, ...
                'mergeUi', @obj.mergeUi, ...
                'runUiAction', @obj.runUiAction, ...
                'showImagingFrame', @(varargin) obj.Imaging.showImagingFrame(varargin{:}), ...
                'uiBuildHelpers', @obj.uiBuildHelpers);
        end

        function ports = stageLaserPorts(obj)
            flir = obj.Flir;
            ports = struct( ...
                'displayYToStage', @obj.displayYToStage, ...
                'flirLive', @flir.flirLive, ...
                'logMessage', @obj.logMessage, ...
                'runUiAction', @obj.runUiAction, ...
                'stageYToDisplay', @obj.stageYToDisplay, ...
                'syncAll', @() obj.UiPolicy.syncAll(), ...
                'syncCurrentXYZLabel', @() obj.UiPolicy.syncCurrentXYZLabel(), ...
                'syncLaserIndicator', @() obj.UiPolicy.syncLaserIndicator(), ...
                'syncPausedUiLight', @() obj.UiPolicy.syncPausedUiLight(), ...
                'syncPreviewCurrentPosition', @() obj.Trajectory.syncPreviewCurrentPosition(), ...
                'syncRunStatus', @() obj.Run.syncRunStatus(), ...
                'validateTargetForUi', @obj.validateTargetForUi);
        end

        function ports = trajectoryPorts(obj)
            ports = struct( ...
                'apply3DPreviewLimits', @() obj.UiPolicy.apply3DPreviewLimits(), ...
                'buildZSweepMatrix', @(varargin) obj.Run.buildZSweepMatrix(varargin{:}), ...
                'clearPreviewColorbar', @() obj.UiPolicy.clearPreviewColorbar(), ...
                'displayYToStage', @obj.displayYToStage, ...
                'logMessage', @obj.logMessage, ...
                'runUiAction', @obj.runUiAction, ...
                'selectedRunMode', @() obj.Run.selectedRunMode(), ...
                'stageLaser', obj.StageLaser, ...
                'stageYToDisplay', @obj.stageYToDisplay, ...
                'syncAll', @() obj.UiPolicy.syncAll(), ...
                'validateTargetForUi', @obj.validateTargetForUi);
        end

        function ports = runPorts(obj, projectRoot)
            ports = struct( ...
                'carbide', obj.Carbide, ...
                'displayYToStage', @obj.displayYToStage, ...
                'logMessage', @obj.logMessage, ...
                'projectRoot', char(projectRoot), ...
                'runUiAction', @obj.runUiAction, ...
                'stageLaser', obj.StageLaser, ...
                'stageYToDisplay', @obj.stageYToDisplay, ...
                'syncAll', @() obj.UiPolicy.syncAll(), ...
                'syncPositionFields', @() obj.UiPolicy.syncPositionFields(), ...
                'trajectory', obj.Trajectory, ...
                'validateTargetForUi', @obj.validateTargetForUi);
        end

        function ports = imagingPorts(obj)
            ports = struct( ...
                'carbide', obj.Carbide, ...
                'displayYToStage', @obj.displayYToStage, ...
                'flir', obj.Flir, ...
                'logMessage', @obj.logMessage, ...
                'runUiAction', @obj.runUiAction, ...
                'stageLaser', obj.StageLaser, ...
                'stageYToDisplay', @obj.stageYToDisplay, ...
                'syncAll', @() obj.UiPolicy.syncAll(), ...
                'syncPositionFields', @() obj.UiPolicy.syncPositionFields(), ...
                'trajectory', obj.Trajectory, ...
                'validateTargetForUi', @obj.validateTargetForUi);
        end

        function ports = uiPolicyPorts(obj)
            ports = struct( ...
                'carbide', obj.Carbide, ...
                'flir', obj.Flir, ...
                'imaging', obj.Imaging, ...
                'isMakoConnected', @obj.isMakoConnected, ...
                'run', obj.Run, ...
                'stageLaser', obj.StageLaser, ...
                'stageYToDisplay', @obj.stageYToDisplay, ...
                'trajectory', obj.Trajectory);
        end

        function ports = safetyPorts(obj)
            ports = struct( ...
                'stopFlirLive', @(resumeLive) obj.Flir.flirLive('stop', resumeLive), ...
                'requestStageStop', @() obj.StageLaser.requestStageStop(), ...
                'forceLaserSafeOff', @() obj.StageLaser.forceLaserSafeOff(), ...
                'stopFlirAcquisition', @obj.stopFlirAcquisition, ...
                'deleteFlirLive', @() obj.Flir.flirLive('delete'), ...
                'stopPositionTimer', @() obj.StageLaser.stopPositionTimer(), ...
                'stopCarbideTimer', @() obj.Carbide.stopCarbideStatusTimer(), ...
                'closeSlmWindow', @obj.closeSlmControlWindow, ...
                'disconnectBatchSlm', @obj.disconnectBatchSlmForShutdown, ...
                'shutdownMako', @obj.shutdownMakoController, ...
                'finalizeRunLog', @obj.finalizeRunLogForShutdown, ...
                'disconnectAll', @obj.disconnectAllForShutdown, ...
                'deleteFigure', @obj.deleteAppFigure, ...
                'updateStopStatus', @obj.updateStopStatus, ...
                'syncAll', @() obj.UiPolicy.syncAll());
        end

        function buildUi(obj)
            obj.Model.Figure = uifigure( ...
                'Name', '3D Laser Writing Control App', ...
                'Position', [80, 60, 1440, 900], ...
                'CloseRequestFcn', @obj.onCloseRequested);

            mainGrid = uigridlayout(obj.Model.Figure, [3, 1], ...
                'RowHeight', {64, '1x', 150}, ...
                'Padding', [10, 10, 10, 10], ...
                'RowSpacing', 10);

            obj.buildStatusBar(mainGrid);
            obj.buildTabs(mainGrid);
            obj.buildLogArea(mainGrid);
        end

        function buildStatusBar(obj, parent)
            callbacks = struct('stopRequested', @obj.onStopRequested);
            obj.mergeUi(lw_build_status_bar(parent, callbacks));
        end

        function buildTabs(obj, parent)
            tabs = uitabgroup(parent);
            tabs.Layout.Row = 2;

            obj.buildControlTab(uitab(tabs, 'Title', 'Control'));
            obj.buildTrajectoryTab(uitab(tabs, 'Title', 'Plan'));
            obj.buildRunTab(uitab(tabs, 'Title', 'Run'));
            obj.buildCameraTab(uitab(tabs, 'Title', 'Camera'));
            obj.buildSlmTab(uitab(tabs, 'Title', 'SLM'));
        end

        function buildCameraTab(obj, tab)
            rootGrid = uigridlayout(tab, [1, 1], ...
                'Padding', [0, 0, 0, 0]);
            cameraTabs = uitabgroup(rootGrid);
            cameraTabs.Layout.Row = 1;
            cameraTabs.Layout.Column = 1;

            makoTab = uitab(cameraTabs, 'Title', 'Mako Monitor & Alignment');
            makoOptions = struct('stateChangedFcn', @obj.onMakoConnectionStateChanged);
            obj.Model.MakoController = obj.Model.Services.mako.create(makoTab, makoOptions);

            flirTab = uitab(cameraTabs, 'Title', 'FLIR 3D Imaging');
            flirGrid = uigridlayout(flirTab, [1, 1], ...
                'Padding', [0, 0, 0, 0]);
            flirTabs = uitabgroup(flirGrid);
            flirTabs.Layout.Row = 1;
            flirTabs.Layout.Column = 1;
            obj.buildImagingTab(uitab(flirTabs, 'Title', 'Single 3D Stack'));
            obj.buildBatchImagingTab(uitab(flirTabs, 'Title', 'Batch Imaging'));
        end

        function onMakoConnectionStateChanged(obj, ~)
            try
                obj.UiPolicy.syncControlEnableStates();
            catch
            end
        end

        function buildSlmTab(obj, tab)
            callbacks = struct( ...
                'openSlmControl', @(~, ~) obj.runUiAction(@() obj.openSlmControlWindowImpl(), ...
                    'Failed to open SLM control'));
            obj.mergeUi(lw_build_slm_tab(tab, callbacks));
        end

        function buildControlTab(obj, tab)
            stageLaser = obj.StageLaser;
            carbide = obj.Carbide;
            trajectory = obj.Trajectory;
            callbacks = struct( ...
                'connectAll', @obj.onConnectAll, ...
                'connectStages', @stageLaser.onConnectStages, ...
                'connectDAQ', @stageLaser.onConnectDAQ, ...
                'connectCarbide', @carbide.onConnectCarbide, ...
                'disconnectCarbide', @carbide.onDisconnectCarbide, ...
                'disconnect', @obj.onDisconnect, ...
                'homeStages', @stageLaser.onHomeStages, ...
                'captureMark', @trajectory.onCaptureMark, ...
                'jog', @stageLaser.onJog, ...
                'useCurrentPosition', @stageLaser.onUseCurrentPosition, ...
                'moveAbsolute', @stageLaser.onMoveAbsolute, ...
                'savePosition', @stageLaser.onSavePosition, ...
                'moveToPosition', @stageLaser.onMoveToPosition, ...
                'laserOn', @stageLaser.onLaserOn, ...
                'laserOff', @stageLaser.onLaserOff, ...
                'enableCarbideOutput', @carbide.onEnableCarbideOutput, ...
                'closeCarbideOutput', @carbide.onCloseCarbideOutput, ...
                'applyCarbidePpDivider', @carbide.onApplyCarbidePpDivider, ...
                'applyCarbidePreset', @carbide.onApplyCarbidePreset, ...
                'standbyCarbide', @carbide.onStandbyCarbide, ...
                'fireExposure', @stageLaser.onFireExposure);
            controlUi = lw_build_control_tab(tab, callbacks, obj.uiBuildHelpers());
            obj.mergeUi(controlUi);
        end

        function buildTrajectoryTab(obj, tab)
            trajectory = obj.Trajectory;
            stageLaser = obj.StageLaser;
            callbacks = struct( ...
                'sourceModeChanged', @trajectory.onSourceModeChanged, ...
                'planPowerChanged', @trajectory.onPlanPowerChanged, ...
                'browseInputFile', @trajectory.onBrowseInputFile, ...
                'importOrGenerateTrajectory', @trajectory.onImportOrGenerateTrajectory, ...
                'useCurrentPosition', @stageLaser.onUseCurrentPosition);
            trajectoryUi = lw_build_trajectory_tab(tab, callbacks, obj.uiBuildHelpers());
            obj.mergeUi(trajectoryUi);
        end

        function buildRunTab(obj, tab)
            trajectory = obj.Trajectory;
            stageLaser = obj.StageLaser;
            runController = obj.Run;
            callbacks = struct( ...
                'runModeChanged', @trajectory.onRunModeChanged, ...
                'zSweepPreviewChanged', @trajectory.onZSweepPreviewChanged, ...
                'zSweepMatrixChanged', @trajectory.onZSweepMatrixChanged, ...
                'useCurrentZSweepPosition', @stageLaser.onUseCurrentZSweepPosition, ...
                'goToFirstPoint', @runController.onGoToFirstPoint, ...
                'checkBounds', @runController.onCheckBounds, ...
                'startRun', @runController.onStartRun, ...
                'pauseResumeRun', @runController.onPauseResumeRun, ...
                'stopRequested', @obj.onStopRequested);
            options = struct( ...
                'zSweepMatrixParameterItems', {zSweepMatrixParameterItems()}, ...
                'zSweepMatrixBlockParameterItems', {zSweepMatrixBlockParameterItems()});
            runUi = lw_build_run_tab(tab, callbacks, obj.uiBuildHelpers(), options);
            obj.mergeUi(runUi);
        end

        function buildImagingTab(obj, tab)
            flir = obj.Flir;
            imaging = obj.Imaging;
            callbacks = struct( ...
                'refreshFlirDevices', @flir.onRefreshFlirDevices, ...
                'connectFlir', @flir.onConnectFlir, ...
                'disconnectFlir', @flir.onDisconnectFlir, ...
                'applyFlirExposure', @flir.onApplyFlirExposure, ...
                'applyFlirGain', @flir.onApplyFlirGain, ...
                'testFlirCapture', @flir.onTestFlirCapture, ...
                'openFlirLiveWindow', @(~, ~) obj.runUiAction(@() obj.Flir.openFlirLiveWindowImpl(), ...
                    'Failed to open FLIR live window'), ...
                'autoExposureChanged', @(~, ~) obj.UiPolicy.syncAll(), ...
                'browseImagingFolder', @imaging.onBrowseImagingFolder, ...
                'setCurrentImagingEnd', @imaging.onSetCurrentImagingEnd, ...
                'setCurrentImagingStart', @imaging.onSetCurrentImagingStart, ...
                'start3DImaging', @imaging.onStart3DImaging, ...
                'stopRequested', @obj.onStopRequested);
            imagingUi = lw_build_imaging_tab(tab, callbacks, obj.uiBuildHelpers());
            obj.mergeUi(imagingUi);
        end

        function buildBatchImagingTab(obj, tab)
            imaging = obj.Imaging;
            batchUi = lw_build_batch_imaging_tab(tab, @imaging.onBatchAction, @obj.onStopRequested);
            obj.mergeUi(batchUi);
        end

        function buildLogArea(obj, parent)
            callbacks = struct( ...
                'clearLog', @obj.onClearLog, ...
                'exportLog', @obj.onExportLog);
            obj.mergeUi(lw_build_log_area(parent, callbacks, obj.uiBuildHelpers()));
        end

        function helpers = uiBuildHelpers(~)
            helpers = struct( ...
                'createGridSplitter', @createGridSplitter, ...
                'enableScrolling', @enableScrolling, ...
                'createRightLabel', @createRightLabel);
        end

        function mergeUi(obj, newUi)
            fieldNames = fieldnames(newUi);
            for fieldIndex = 1:numel(fieldNames)
                obj.Model.Ui.(fieldNames{fieldIndex}) = newUi.(fieldNames{fieldIndex});
            end
        end

        function onClearLog(obj, ~, ~)
            obj.Model.Ui.LogTextArea.Value = cell(0, 1);
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function onExportLog(obj, ~, ~)
            logLines = obj.normalizedLogLines();
            timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            defaultName = sprintf('laser_writing_log_%s.txt', timestamp);
            [fileName, folderName] = obj.Model.Services.dialog.saveFile( ...
                {'*.txt', 'Text Files (*.txt)'; '*.log', 'Log Files (*.log)'; '*.*', 'All Files (*.*)'}, ...
                'Export Log', defaultName);
            if isequal(fileName, 0) || isequal(folderName, 0)
                return;
            end

            outputPath = fullfile(folderName, fileName);
            fileId = fopen(outputPath, 'w');
            if fileId < 0
                error('Could not open log export file: %s', outputPath);
            end
            cleanupObj = onCleanup(@() fclose(fileId));

            for i = 1:numel(logLines)
                fprintf(fileId, '%s\n', char(logLines{i}));
            end
            clear cleanupObj

            obj.logMessage(sprintf('Log exported to %s.', outputPath));
        end

        function logLines = normalizedLogLines(obj)
            rawValue = obj.Model.Ui.LogTextArea.Value;
            if isstring(rawValue)
                logLines = cellstr(rawValue(:));
            elseif ischar(rawValue)
                logLines = cellstr(rawValue);
            elseif iscell(rawValue)
                logLines = rawValue(:);
            else
                logLines = cellstr(string(rawValue(:)));
            end
        end

        function resetFieldsFromConfig(obj)
            obj.StageLaser.configureMotionNumberFormats();
            defaults = struct( ...
                'centerDisplayY', obj.stageYToDisplay(obj.Model.Config.motion.centerPosition.y), ...
                'flirGain', obj.Flir.flirLiveGainValue(), ...
                'autoExposureEnabled', obj.Flir.imagingConfigValue('autoExposureEnabled', true), ...
                'autoExposureSampleCount', obj.Flir.imagingConfigValue('autoExposureSampleCount', 5), ...
                'autoExposureSafetyFactor', obj.Flir.imagingConfigValue('autoExposureSafetyFactor', 0.8));
            lw_reset_fields_from_config(obj.Model.Ui, obj.Model.Config, defaults);
        end

        function onConnectAll(obj, ~, ~)
            obj.runUiAction(@() obj.connectAllImpl(), 'Failed to connect all hardware');
        end

        function openSlmControlWindowImpl(obj)
            if isValidUiHandle(obj.Model.Ui.SlmControlFigure)
                figure(obj.Model.Ui.SlmControlFigure);
                try
                    obj.Model.Ui.SlmControlFigure.Visible = 'on';
                catch
                end
                return;
            end

            obj.Model.Ui.SlmControlFigure = obj.Model.Services.slm.openControl();
            obj.logMessage('SLM control window opened.');
        end

        function closeSlmControlWindow(obj)
            slmFigure = [];
            if isfield(obj.Model.Ui, 'SlmControlFigure')
                slmFigure = obj.Model.Ui.SlmControlFigure;
            end
            obj.Model.Ui.SlmControlFigure = [];
            try
                if isValidUiHandle(slmFigure)
                    close(slmFigure);
                end
            catch
            end
        end

        function connectAllImpl(obj)
            failureMessages = strings(1, 0);
            attemptedCount = 0;

            if ~obj.StageLaser.areStagesConnected()
                attemptedCount = attemptedCount + 1;
                try
                    obj.StageLaser.connectStagesImpl();
                catch ME
                    failureMessages(end + 1) = "Stages: " + string(compactErrorMessage(ME));
                    obj.logMessage(sprintf('Connect All could not connect stages: %s', compactErrorMessage(ME)));
                end
            end

            if ~obj.StageLaser.areDAQConnected()
                attemptedCount = attemptedCount + 1;
                try
                    obj.StageLaser.connectDAQImpl();
                catch ME
                    failureMessages(end + 1) = "DAQ: " + string(compactErrorMessage(ME));
                    obj.logMessage(sprintf('Connect All could not connect DAQ: %s', compactErrorMessage(ME)));
                end
            end

            if obj.Carbide.isCarbideEnabled() && ~obj.Carbide.areCarbideConnected()
                attemptedCount = attemptedCount + 1;
                try
                    obj.Carbide.connectCarbideImpl();
                catch ME
                    failureMessages(end + 1) = "Carbide: " + string(compactErrorMessage(ME));
                    obj.logMessage(sprintf('Connect All could not connect Carbide: %s', compactErrorMessage(ME)));
                end
            end

            if ~isempty(failureMessages)
                error('Connect All completed with errors: %s', char(strjoin(failureMessages, '; ')));
            end
            if attemptedCount == 0
                obj.logMessage('All configured hardware is already connected.');
            else
                obj.logMessage('Connect All completed.');
            end
        end

        function onDisconnect(obj, ~, ~)
            obj.runUiAction(@() obj.disconnectImpl(), 'Failed to disconnect cleanly');
        end

        function disconnectImpl(obj)
            obj.Flir.flirLive('stop', false);
            obj.StageLaser.stopPositionTimer();
            obj.disconnectMakoController(false);
            obj.Model.State = obj.Model.Services.stage.disconnectAll(obj.Model.State, obj.Model.Config);
            obj.Model.RunCurrentText = "Idle";
            obj.Model.RunProgressText = "0 / 0";
            obj.Model.ImagingCurrentText = "Idle";
            obj.Model.ImagingProgressText = "0 / 0";
            obj.Model.ImagingRunActive = false;
            obj.Flir.refreshFlirDeviceDropDown();
            obj.logMessage('Hardware disconnected and outputs reset.');
        end

        function disconnectMakoController(obj, quiet)
            if nargin < 2
                quiet = false;
            end
            if isempty(obj.Model.MakoController) || ~isstruct(obj.Model.MakoController) || ...
                    ~isfield(obj.Model.MakoController, 'disconnect')
                return
            end
            try
                obj.Model.Services.mako.disconnect(obj.Model.MakoController);
            catch ME
                if ~quiet
                    obj.logMessage(sprintf('Mako disconnect warning: %s', compactErrorMessage(ME)));
                end
            end
        end

        function shutdownMakoController(obj)
            if isempty(obj.Model.MakoController) || ~isstruct(obj.Model.MakoController) || ...
                    ~isfield(obj.Model.MakoController, 'shutdown')
                return
            end
            try
                obj.Model.Services.mako.shutdown(obj.Model.MakoController);
            catch
            end
        end

        function tf = isMakoConnected(obj)
            tf = false;
            if isempty(obj.Model.MakoController) || ~isstruct(obj.Model.MakoController) || ...
                    ~isfield(obj.Model.MakoController, 'isConnected')
                return
            end
            try
                tf = obj.Model.Services.mako.isConnected(obj.Model.MakoController);
            catch
                tf = false;
            end
        end

        function onStopRequested(obj, ~, ~)
            obj.Safety.requestStop();
        end

        function stopFlirAcquisition(obj)
            if isfield(obj.Model.State, 'flir') && isstruct(obj.Model.State.flir) && ...
                    isfield(obj.Model.State.flir, 'isAcquiring') && logical(obj.Model.State.flir.isAcquiring)
                obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
            end
        end

        function updateStopStatus(obj, wasPaused, wasBusy)
            if obj.Model.State.isBusy
                obj.Model.RunCurrentText = obj.Run.formatRunStatusWithCurrentPosition("Stop requested");
                if obj.Model.ImagingRunActive
                    obj.Model.ImagingCurrentText = "Stop requested";
                end
                obj.logMessage('STOP requested.');
            elseif wasPaused
                obj.Model.RunCurrentText = obj.Run.formatRunStatusWithCurrentPosition("Stopped");
                obj.logMessage('STOP requested while paused. Resume context cleared and outputs forced off.');
            else
                obj.logMessage('STOP requested while idle. Outputs forced off.');
            end
            if wasPaused && ~wasBusy
                try
                    obj.Model.RunLog = lw_run_log('finalize', obj.Model.RunLog, "stopped", ...
                        obj.Run.makeRunResult("stopped", obj.Run.localCurrentRunTarget(), []), obj.Model.State, obj.Model.Config, []);
                catch
                end
            end
        end

        function onCloseRequested(obj, ~, ~)
            obj.Safety.shutdown();
        end

        function disconnectBatchSlmForShutdown(obj)
            imaging = obj.Imaging;
            obj.Model.Services.slm.batchAction( ...
                obj.Model.Figure, 'disconnectSlmSilent', obj.Model.Ui, @imaging.batchExecutionApi);
        end

        function finalizeRunLogForShutdown(obj)
            obj.Model.RunLog = lw_run_log('finalize', obj.Model.RunLog, "app_closed", ...
                obj.Run.makeRunResult("app_closed", obj.Run.localCurrentRunTarget(), []), obj.Model.State, obj.Model.Config, []);
        end

        function disconnectAllForShutdown(obj)
            obj.Model.State = obj.Model.Services.stage.disconnectAll(obj.Model.State, obj.Model.Config);
        end

        function deleteAppFigure(obj)
            delete(obj.Model.Figure);
        end

        function runUiAction(obj, actionFcn, failurePrefix)
            try
                actionFcn();
                obj.syncAfterUiAction();
            catch ME
                obj.syncAfterUiAction();
                obj.reportError(failurePrefix, ME);
            end
        end

        function syncAfterUiAction(obj)
            if obj.Model.State.isPaused
                obj.UiPolicy.syncPausedUiLight();
            else
                obj.UiPolicy.syncAll();
            end
        end

        function reportError(obj, prefix, err)
            message = sprintf('%s: %s', prefix, err.message);
            obj.logMessage(message);
            try
                obj.Model.Services.dialog.alert(obj.Model.Figure, message, 'Laser Writing App');
            catch
            end
        end

        function validateTargetForUi(obj, target, actionLabel)
            lw_validate_target_for_ui(target, obj.Model.Config.motion.travelLimits, ...
                obj.Model.Config.motion.yDisplayReference, actionLabel);
        end

        function displayY = stageYToDisplay(obj, stageY)
            displayY = obj.Model.Config.motion.yDisplayReference - stageY;
        end

        function stageY = displayYToStage(obj, displayY)
            stageY = obj.Model.Config.motion.yDisplayReference - displayY;
        end

        function logMessage(obj, message)
            line = lw_log(obj.Model.Ui, message);
            try
                obj.Model.RunLog = lw_run_log('message', obj.Model.RunLog, line, message);
            catch
            end
        end
    end
end
