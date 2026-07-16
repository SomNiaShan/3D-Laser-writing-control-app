classdef ImagingController < handle
    %IMAGINGCONTROLLER Orchestrate single/batch imaging, output, and auto exposure.

    properties (SetAccess = private)
        Model
        Ports
    end

    methods
        function obj = ImagingController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("ImagingController", ports, [ ...
                "carbide", "displayYToStage", "flir", "logMessage", "runUiAction", ...
                "stageLaser", "stageYToDisplay", "syncAll", "syncPositionFields", ...
                "trajectory", "validateTargetForUi"]);
        end

        function onBrowseImagingFolder(obj, ~, ~)
            selectedFolder = obj.Model.Services.dialog.chooseFolder( ...
                obj.Model.Ui.ImagingFolderField.Value, 'Select 3D imaging output folder');
            if isequal(selectedFolder, 0)
                return;
            end
            obj.Model.Ui.ImagingFolderField.Value = selectedFolder;
            obj.Ports.logMessage(sprintf('3D imaging output folder set to: %s', selectedFolder));
        end

        function onSetCurrentImagingEnd(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.setCurrentImagingEndpointImpl('end'), ...
                'Failed to set current position as imaging end');
        end

        function onSetCurrentImagingStart(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.setCurrentImagingEndpointImpl('start'), ...
                'Failed to set current position as imaging start');
        end

        function setCurrentImagingEndpointImpl(obj, endpoint)
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
            obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
            obj.Model.Ui.ImagingXField.Value = obj.Model.State.currentPosition.x;
            obj.Model.Ui.ImagingYField.Value = obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y);

            switch endpoint
                case 'start'
                    obj.Model.Ui.ImagingZStartField.Value = obj.Model.State.currentPosition.z;
                    endpointText = 'start';
                case 'end'
                    obj.Model.Ui.ImagingZEndField.Value = obj.Model.State.currentPosition.z;
                    endpointText = 'end';
                otherwise
                    error('laserWritingApp:InvalidImagingEndpoint', ...
                        'Unknown 3D imaging endpoint: %s', endpoint);
            end

            obj.Model.ImagingCurrentText = sprintf('Current position set as 3D imaging %s: X %.3f, Y %.3f, Z %.3f mm', ...
                endpointText, obj.Model.State.currentPosition.x, obj.Ports.stageYToDisplay(obj.Model.State.currentPosition.y), obj.Model.State.currentPosition.z);
            obj.Ports.logMessage(obj.Model.ImagingCurrentText);
        end

        function onStart3DImaging(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused
                return;
            end
            obj.Ports.runUiAction(@() obj.start3DImagingImpl(), '3D imaging failed');
        end

        function start3DImagingImpl(obj)
            resumeLive = obj.Ports.flir.flirLive('pause', 'Paused for 3D imaging');
            liveCleanupObj = onCleanup(@() obj.Ports.flir.flirLive('resume', resumeLive));
            preflight = obj.build3DImagingPreflight();
            choice = string(obj.Model.Services.dialog.confirm( ...
                obj.Model.Figure, preflight.summaryText, '3D Imaging Preflight', ...
                'Options', {'Start', 'Cancel'}, ...
                'DefaultOption', 'Start', ...
                'CancelOption', 'Cancel', ...
                'Icon', 'question'));
            if choice ~= "Start"
                obj.Model.ImagingProgressText = "Preflight cancelled";
                obj.Model.ImagingCurrentText = "Preflight cancelled";
                obj.Ports.logMessage('3D imaging cancelled at preflight.');
                return;
            end

            obj.begin3DImagingExecution(preflight);
            try
                imagingResult = obj.execute3DImaging(preflight);
                obj.complete3DImagingExecution(imagingResult);
            catch ME
                obj.finish3DImagingCleanup();
                rethrow(ME);
            end
            clear liveCleanupObj
        end

        function onBatchAction(obj, action, varargin)
            action = string(action);
            if action == "startBatch" && (obj.Model.State.isBusy || obj.Model.State.isPaused)
                return;
            end

            if any(action == ["tableSelection", "tableEdited", "disconnectSlmSilent"])
                obj.Model.Services.slm.batchAction( ...
                    obj.Model.Figure, action, obj.Model.Ui, @obj.batchExecutionApi, varargin{:});
                return;
            end

            obj.Ports.runUiAction(@() obj.Model.Services.slm.batchAction( ...
                obj.Model.Figure, action, obj.Model.Ui, @obj.batchExecutionApi, varargin{:}), ...
                lw_batch_action_failure_prefix(action));
        end

        function varargout = batchExecutionApi(obj, action, varargin)
            switch string(action)
                case "buildPreflight"
                    varargout{1} = obj.buildBatchImagingPreflight(varargin{1});
                case "begin"
                    preflight = varargin{1};
                    obj.Model.State.stopRequested = false;
                    obj.Model.State.pauseRequested = false;
                    obj.Model.State.isPaused = false;
                    obj.Model.State.resumeContext = [];
                    obj.Model.State.isBusy = true;
                    obj.Model.ImagingRunActive = true;
                    obj.Model.ImagingEtaStartTic = [];
                    obj.Model.BatchProgressText = sprintf('0 / %d (Preparing)', numel(preflight.jobs));
                    obj.Model.BatchCurrentText = "Preparing";
                    obj.Model.BatchOutputText = string(preflight.runFolder);
                    obj.Model.ImagingProgressText = "0 / 0";
                    obj.Model.ImagingCurrentText = "Preparing batch";
                    obj.Ports.syncAll();
                    obj.Ports.logMessage(sprintf('Batch imaging started: %d SLM row(s), %d total frame(s), output %s.', ...
                        numel(preflight.jobs), preflight.totalFrames, preflight.runFolder));
                case "setStatus"
                    obj.Model.BatchProgressText = string(varargin{1});
                    obj.Model.BatchCurrentText = string(varargin{2});
                    obj.syncBatchStatus();
                    obj.Model.Services.ui.drawnow('limitrate');
                case "setOutput"
                    obj.Model.BatchOutputText = string(varargin{1});
                    obj.Model.Ui.BatchOutputField.Value = char(obj.Model.BatchOutputText);
                case "isStopRequested"
                    varargout{1} = obj.Ports.stageLaser.isStopRequested();
                case "finishCleanup"
                    obj.finish3DImagingCleanup();
                case "flirLive"
                    [varargout{1:nargout}] = obj.Ports.flir.flirLive(varargin{:});
                case "pauseWithUi"
                    obj.Ports.stageLaser.pauseWithUi(varargin{1});
                case "patternContext"
                    varargout{1} = obj.batchSlmGenerationContext(varargin{1});
                case "isBatchSlmConnected"
                    varargout{1} = obj.isBatchSlmConnected();
                case "isFigValid"
                    varargout{1} = isValidUiHandle(obj.Model.Figure);
                case "slmSnapshotKey"
                    varargout{1} = lw_slm_drill_snapshot_app_data_key();
                case "buildJobPreflight"
                    batchPreflight = varargin{1};
                    job = varargin{2};
                    snapshot = varargin{3};
                    imagingPreflight = obj.build3DImagingPreflight();
                    imagingPreflight.motion = batchPreflight.motion;
                    imagingPreflight.x = batchPreflight.x;
                    imagingPreflight.displayY = batchPreflight.displayY;
                    imagingPreflight.y = batchPreflight.y;
                    imagingPreflight.zStart = batchPreflight.zStart;
                    imagingPreflight.zEnd = batchPreflight.zEnd;
                    imagingPreflight.zStep = batchPreflight.zStep;
                    imagingPreflight.settlingTime = batchPreflight.settlingTime;
                    imagingPreflight.captureTimeoutMs = batchPreflight.captureTimeoutMs;
                    imagingPreflight.exposureUs = batchPreflight.exposureUs;
                    imagingPreflight.gain = batchPreflight.gain;
                    imagingPreflight.autoExposure = batchPreflight.autoExposure;
                    imagingPreflight.zPositions = batchPreflight.zPositions;
                    imagingPreflight.userPrefix = batchPreflight.userPrefix;
                    imagingPreflight.baseFolder = batchPreflight.baseFolder;
                    imagingPreflight.slmSnapshot = snapshot;
                    imagingPreflight.slmFilenameToken = lw_slm_filename_token(snapshot);
                    jobFolderToken = sanitizeFileComponent(sprintf('%03d_%s_%s', ...
                        job.batchIndex, job.name, char(imagingPreflight.slmFilenameToken)), ...
                        sprintf('%03d_slm_job', job.batchIndex));
                    imagingPreflight.prefix = sanitizeFileComponent(sprintf('%s_%s', ...
                        batchPreflight.userPrefix, jobFolderToken), 'beam_stack');
                    imagingPreflight.runFolder = fullfile(batchPreflight.runFolder, jobFolderToken);
                    imagingPreflight.stackFileName = imagingStackFilename(imagingPreflight.prefix);
                    imagingPreflight.stackFile = fullfile(imagingPreflight.runFolder, imagingPreflight.stackFileName);
                    varargout{1} = imagingPreflight;
                case "execute3D"
                    varargout{1} = obj.execute3DImaging(varargin{1});
                case "syncBatchStatus"
                    obj.syncBatchStatus();
                case "syncAll"
                    obj.Ports.syncAll();
                case "updateBatchSummary"
                    obj.updateBatchTableSummary();
                case "log"
                    obj.Ports.logMessage(varargin{1});
                otherwise
                    error('Unknown batch execution API action: %s.', string(action));
            end
        end

        function preflight = build3DImagingPreflight(obj)
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.flir.requireFlirConnected();

            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            preflight.x = finiteScalar(obj.Model.Ui.ImagingXField.Value, '3D imaging X');
            preflight.displayY = finiteScalar(obj.Model.Ui.ImagingYField.Value, '3D imaging Y');
            preflight.y = obj.Ports.displayYToStage(preflight.displayY);
            preflight.zStart = finiteScalar(obj.Model.Ui.ImagingZStartField.Value, '3D imaging Z start');
            preflight.zEnd = finiteScalar(obj.Model.Ui.ImagingZEndField.Value, '3D imaging Z end');
            preflight.zStep = positiveScalar(obj.Model.Ui.ImagingZStepField.Value, '3D imaging Z step');
            preflight.settlingTime = nonnegativeScalar(obj.Model.Ui.ImagingSettleField.Value, '3D imaging settling time');
            preflight.captureTimeoutMs = positiveInteger(obj.Model.Ui.ImagingTimeoutField.Value, '3D imaging capture timeout');
            preflight.exposureUs = positiveScalar(obj.Model.Ui.FlirExposureField.Value, 'FLIR exposure');
            preflight.gain = nonnegativeScalar(obj.Model.Ui.FlirGainField.Value, 'FLIR gain');
            preflight.autoExposure = obj.imagingAutoExposureOptionsFromUi('3D imaging');
            preflight.zPositions = imagingZPositions(preflight.zStart, preflight.zEnd, preflight.zStep);
            preflight.userPrefix = sanitizeFileComponent(obj.Model.Ui.ImagingPrefixField.Value, 'beam_stack');
            preflight.slmSnapshot = lw_current_slm_drill_snapshot();
            preflight.slmFilenameToken = lw_slm_filename_token(preflight.slmSnapshot);
            preflight.prefix = lw_imaging_prefix_with_slm_token(preflight.userPrefix, preflight.slmFilenameToken);
            preflight.baseFolder = char(strtrim(string(obj.Model.Ui.ImagingFolderField.Value)));
            if isempty(preflight.baseFolder)
                error('3D imaging output folder is empty.');
            end
            preflight.runFolder = fullfile(preflight.baseFolder, ...
                sprintf('%s_%s', preflight.prefix, char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
            preflight.stackFileName = imagingStackFilename(preflight.prefix);
            preflight.stackFile = fullfile(preflight.runFolder, preflight.stackFileName);

            obj.Ports.validateTargetForUi(struct('x', preflight.x, 'y', preflight.y, 'z', preflight.zStart), '3D imaging');
            obj.Ports.validateTargetForUi(struct('x', preflight.x, 'y', preflight.y, 'z', preflight.zEnd), '3D imaging');
            preflight.summaryText = lw_build_3d_imaging_preflight_summary_text( ...
                preflight, obj.Ports.stageLaser.areStagesConnected(), obj.Ports.flir.isFlirConnected());
        end

        function options = imagingAutoExposureOptionsFromUi(obj, label)
            options = struct( ...
                'enabled', false, ...
                'sampleCount', 5, ...
                'safetyFactor', obj.Ports.flir.imagingConfigValue('autoExposureSafetyFactor', 0.8), ...
                'maxRetries', 8);
            if obj.Ports.flir.hasValidUiControl('ImagingAutoExposureCheckBox')
                options.enabled = logical(obj.Model.Ui.ImagingAutoExposureCheckBox.Value);
            end
            if obj.Ports.flir.hasValidUiControl('ImagingAutoExposureSamplesField')
                options.sampleCount = positiveInteger( ...
                    obj.Model.Ui.ImagingAutoExposureSamplesField.Value, ...
                    sprintf('%s auto exposure Z samples', label));
            end
            if obj.Ports.flir.hasValidUiControl('ImagingAutoExposureSafetyFactorField')
                options.safetyFactor = finiteScalar( ...
                    obj.Model.Ui.ImagingAutoExposureSafetyFactorField.Value, ...
                    sprintf('%s auto exposure safety factor', label));
            end
            options.safetyFactor = double(options.safetyFactor);
            if ~isscalar(options.safetyFactor) || ~isfinite(options.safetyFactor) || ...
                    options.safetyFactor <= 0 || options.safetyFactor >= 1
                error('%s auto exposure safety factor must be between 0 and 1.', label);
            end
        end

        function textValue = formatImagingAutoExposureSummary(~, options)
            if ~isstruct(options) || ~isfield(options, 'enabled') || ~logical(options.enabled)
                textValue = "Off";
                return;
            end
            sampleCount = 0;
            if isfield(options, 'sampleCount')
                sampleCount = options.sampleCount;
            end
            safetyFactor = 0.8;
            if isfield(options, 'safetyFactor')
                safetyFactor = options.safetyFactor;
            end
            safetyPercent = 100 * safetyFactor;
            textValue = sprintf('On (%d Z samples, %.0f%% no-clip target)', sampleCount, safetyPercent);
        end

        function preflight = buildBatchImagingPreflight(obj, requireHardware)
            if nargin < 2
                requireHardware = true;
            end
            if requireHardware
                obj.Ports.stageLaser.requireStagesConnected();
                obj.Ports.flir.requireFlirConnected();
                obj.requireBatchSlmConnected();
            end

            jobs = batchJobsFromTable(obj.Model.Ui.BatchSlmTable, true);
            if isempty(jobs)
                error('Batch table has no enabled rows.');
            end

            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            preflight.x = finiteScalar(obj.Model.Ui.ImagingXField.Value, 'Batch imaging X');
            preflight.displayY = finiteScalar(obj.Model.Ui.ImagingYField.Value, 'Batch imaging Y');
            preflight.y = obj.Ports.displayYToStage(preflight.displayY);
            preflight.zStart = finiteScalar(obj.Model.Ui.ImagingZStartField.Value, 'Batch imaging Z start');
            preflight.zEnd = finiteScalar(obj.Model.Ui.ImagingZEndField.Value, 'Batch imaging Z end');
            preflight.zStep = positiveScalar(obj.Model.Ui.ImagingZStepField.Value, 'Batch imaging Z step');
            preflight.settlingTime = nonnegativeScalar(obj.Model.Ui.ImagingSettleField.Value, 'Batch imaging settling time');
            preflight.captureTimeoutMs = positiveInteger(obj.Model.Ui.ImagingTimeoutField.Value, 'Batch imaging capture timeout');
            preflight.exposureUs = positiveScalar(obj.Model.Ui.FlirExposureField.Value, 'FLIR exposure');
            preflight.gain = nonnegativeScalar(obj.Model.Ui.FlirGainField.Value, 'FLIR gain');
            preflight.autoExposure = obj.imagingAutoExposureOptionsFromUi('Batch imaging');
            preflight.zPositions = imagingZPositions(preflight.zStart, preflight.zEnd, preflight.zStep);
            preflight.framesPerJob = numel(preflight.zPositions);
            preflight.totalFrames = preflight.framesPerJob * numel(jobs);
            preflight.userPrefix = sanitizeFileComponent(obj.Model.Ui.ImagingPrefixField.Value, 'beam_stack');
            preflight.batchName = sanitizeFileComponent(obj.Model.Ui.BatchNameField.Value, 'slm_batch');
            preflight.baseFolder = char(strtrim(string(obj.Model.Ui.ImagingFolderField.Value)));
            if isempty(preflight.baseFolder)
                error('Batch imaging output folder is empty.');
            end
            preflight.runFolder = fullfile(preflight.baseFolder, ...
                sprintf('%s_%s', preflight.batchName, char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
            preflight.tableFile = fullfile(preflight.runFolder, 'batch_table.csv');
            preflight.manifestFile = fullfile(preflight.runFolder, 'batch_manifest.csv');
            preflight.jobs = jobs;
            preflight.sourceTable = batchUiDataAsTable(obj.Model.Ui.BatchSlmTable);

            obj.Ports.validateTargetForUi(struct('x', preflight.x, 'y', preflight.y, 'z', preflight.zStart), 'Batch imaging');
            obj.Ports.validateTargetForUi(struct('x', preflight.x, 'y', preflight.y, 'z', preflight.zEnd), 'Batch imaging');
            preflight.summaryText = sprintf([ ...
                'Mode: SLM Batch Z Stack\n', ...
                'SLM Jobs: %d\n', ...
                'Frames per Job: %d\n', ...
                'Total Frames: %d\n', ...
                'X: %.3f mm\n', ...
                'Y: %.3f mm\n', ...
                'Z: %.3f to %.3f mm\n', ...
                'Z Step: %.3f mm\n', ...
                'Stage Settle: %.3f s\n', ...
                'FLIR Exposure: %.6g us\n', ...
                'Auto Exposure: %s\n', ...
                'FLIR Gain: %.6g dB\n', ...
                'Capture Timeout: %d ms\n', ...
                'Output Folder: %s\n', ...
                'Batch Table: %s\n', ...
                'Manifest: %s\n', ...
                'Hardware: Stage %s | FLIR %s | Batch SLM %s'], ...
                numel(preflight.jobs), preflight.framesPerJob, preflight.totalFrames, ...
                preflight.x, preflight.displayY, preflight.zStart, preflight.zEnd, ...
                preflight.zStep, preflight.settlingTime, preflight.exposureUs, ...
                char(obj.formatImagingAutoExposureSummary(preflight.autoExposure)), ...
                preflight.gain, preflight.captureTimeoutMs, preflight.runFolder, ...
                preflight.tableFile, preflight.manifestFile, ...
                connectionText(obj.Ports.stageLaser.areStagesConnected()), connectionText(obj.Ports.flir.isFlirConnected()), ...
                connectionText(obj.isBatchSlmConnected()));
        end

        function controllerState = batchControllerState(obj)
            controllerState = struct('selectedRows', [], 'slmCtx', []);
            try
                key = lw_batch_state_appdata_key();
                if isappdata(obj.Model.Figure, key)
                    storedState = getappdata(obj.Model.Figure, key);
                    if isstruct(storedState)
                        if isfield(storedState, 'selectedRows')
                            controllerState.selectedRows = storedState.selectedRows;
                        end
                        if isfield(storedState, 'slmCtx')
                            controllerState.slmCtx = storedState.slmCtx;
                        end
                    end
                end
            catch
            end
        end

        function ctx = batchSlmGenerationContext(obj, requireHardware)
            if nargin < 2
                requireHardware = false;
            end
            if obj.isBatchSlmConnected()
                controllerState = obj.batchControllerState();
                ctx = controllerState.slmCtx;
                return;
            end
            if requireHardware
                obj.requireBatchSlmConnected();
            end

            cfg = slm_config();
            ctx = struct( ...
                'widthPx', cfg.expectedWidthPx, ...
                'heightPx', cfg.expectedHeightPx, ...
                'config', cfg);
        end

        function updateBatchTableSummary(obj)
            if ~isfield(obj.Model.Ui, 'BatchTableSummaryLabel') || isempty(obj.Model.Ui.BatchTableSummaryLabel)
                return;
            end
            try
                data = batchNormalizedTableData(obj.Model.Ui.BatchSlmTable);
                jobs = batchJobsFromTable(obj.Model.Ui.BatchSlmTable, true);
                zPositions = imagingZPositions( ...
                    finiteScalar(obj.Model.Ui.ImagingZStartField.Value, 'Batch summary Z start'), ...
                    finiteScalar(obj.Model.Ui.ImagingZEndField.Value, 'Batch summary Z end'), ...
                    positiveScalar(obj.Model.Ui.ImagingZStepField.Value, 'Batch summary Z step'));
                totalFrames = numel(jobs) * numel(zPositions);
                obj.Model.Ui.BatchTableSummaryLabel.Text = sprintf('%d row(s), %d enabled, %d Z plane(s), %d total frame(s).', ...
                    size(data, 1), numel(jobs), numel(zPositions), totalFrames);
                autoExposure = obj.imagingAutoExposureOptionsFromUi('Batch summary');
                obj.Model.Ui.BatchCommonSettingsLabel.Text = sprintf('Common Z stack: X %.3f | Y %.3f | Z %.3f to %.3f step %.3f | exposure %.6g us | auto %s', ...
                    obj.Model.Ui.ImagingXField.Value, obj.Model.Ui.ImagingYField.Value, obj.Model.Ui.ImagingZStartField.Value, ...
                    obj.Model.Ui.ImagingZEndField.Value, obj.Model.Ui.ImagingZStepField.Value, obj.Model.Ui.FlirExposureField.Value, ...
                    char(obj.formatImagingAutoExposureSummary(autoExposure)));
            catch ME
                obj.Model.Ui.BatchTableSummaryLabel.Text = sprintf('Batch table needs attention: %s', ME.message);
                obj.Model.Ui.BatchCommonSettingsLabel.Text = 'Common Z stack settings come from the 3D Imaging tab.';
            end
        end

        function syncBatchStatus(obj)
            if ~isfield(obj.Model.Ui, 'BatchProgressField') || isempty(obj.Model.Ui.BatchProgressField)
                return;
            end
            obj.Model.Ui.BatchProgressField.Value = char(obj.Model.BatchProgressText);
            obj.Model.Ui.BatchCurrentField.Value = char(obj.Model.BatchCurrentText);
            obj.Model.Ui.BatchOutputField.Value = char(obj.Model.BatchOutputText);
            if obj.isBatchSlmConnected()
                controllerState = obj.batchControllerState();
                obj.Model.Ui.BatchSlmStatusLabel.Text = sprintf('Connected: %d x %d px', ...
                    controllerState.slmCtx.widthPx, controllerState.slmCtx.heightPx);
            else
                obj.Model.Ui.BatchSlmStatusLabel.Text = 'Disconnected';
            end
            obj.updateBatchTableSummary();
        end

        function tf = isBatchSlmConnected(obj)
            controllerState = obj.batchControllerState();
            slmCtx = controllerState.slmCtx;
            tf = isstruct(slmCtx) && ~isempty(slmCtx) && ...
                isfield(slmCtx, 'slm') && isfield(slmCtx, 'widthPx') && ...
                isfield(slmCtx, 'heightPx');
        end

        function requireBatchSlmConnected(obj)
            if ~obj.isBatchSlmConnected()
                error('Batch SLM is not connected. Use Connect SLM in the Batch Imaging tab.');
            end
        end

        function begin3DImagingExecution(obj, preflight)
            obj.Model.State.stopRequested = false;
            obj.Model.State.pauseRequested = false;
            obj.Model.State.isPaused = false;
            obj.Model.State.resumeContext = [];
            obj.Model.State.isBusy = true;
            obj.Model.ImagingRunActive = true;
            obj.Model.ImagingEtaStartTic = [];
            obj.Model.ImagingProgressText = obj.formatImagingProgressText(0, numel(preflight.zPositions), "Preparing");
            obj.Model.ImagingCurrentText = "Preparing";
            obj.Ports.syncAll();
            obj.Ports.logMessage(sprintf('3D imaging started: %d Z plane(s), output %s.', ...
                numel(preflight.zPositions), preflight.runFolder));
        end

        function result = execute3DImaging(obj, preflight)
            metadataRows = lw_empty_imaging_metadata_rows();
            metadataFile = fullfile(preflight.runFolder, 'metadata.csv');
            result = struct( ...
                'status', "finished", ...
                'capturedCount', 0, ...
                'totalCount', numel(preflight.zPositions), ...
                'outputFolder', string(preflight.runFolder), ...
                'stackFile', string(preflight.stackFile), ...
                'metadataFile', string(metadataFile), ...
                'actualExposureUs', NaN, ...
                'autoExposureEnabled', false, ...
                'autoExposureScoutCount', 0, ...
                'autoExposureScoutFile', "");
            acquisitionStarted = false;

            if ~isfolder(preflight.runFolder)
                mkdir(preflight.runFolder);
            end

            try
                [obj.Model.State.flir, actualExposureUs] = obj.Model.Services.flir.setExposure( ...
                    obj.Model.State.flir, preflight.exposureUs);
                obj.Model.Ui.FlirExposureField.Value = actualExposureUs;
                [obj.Model.State.flir, actualGain] = obj.Model.Services.flir.setGain( ...
                    obj.Model.State.flir, preflight.gain);
                obj.Model.Ui.FlirGainField.Value = actualGain;
                obj.Ports.flir.syncFlirLiveWindowFieldsFromMain();
                [obj.Model.State.flir, width, height, regionInfo] = ...
                    obj.Model.Services.flir.setCaptureRegion( ...
                    obj.Model.State.flir, obj.Ports.flir.flirCaptureRegion());
                moveOptions = struct( ...
                    'shouldStopFcn', @() obj.Ports.stageLaser.isStopRequested(), ...
                    'yieldFcn', @() obj.Ports.stageLaser.yieldWithLivePosition(), ...
                    'pollIntervalSeconds', 0.02);
                obj.Model.State.flir = obj.Model.Services.flir.startAcquisition(obj.Model.State.flir);
                acquisitionStarted = true;
                obj.Ports.logMessage(sprintf('FLIR acquisition started at %d x %d (%s), exposure %.6g us, gain %.6g dB.', ...
                    width, height, char(regionInfo.Name), actualExposureUs, actualGain));

                scoutStopped = false;
                if obj.imagingAutoExposureEnabled(preflight)
                    [actualExposureUs, autoExposureResult, acquisitionStarted, scoutStopped] = ...
                        obj.runImagingAutoExposureScout(preflight, actualExposureUs, acquisitionStarted, moveOptions);
                    result.actualExposureUs = actualExposureUs;
                    result.autoExposureEnabled = true;
                    result.autoExposureScoutCount = autoExposureResult.scoutCount;
                    result.autoExposureScoutFile = string(autoExposureResult.scoutFile);
                    if scoutStopped
                        result.status = "stopped";
                    end
                else
                    result.actualExposureUs = actualExposureUs;
                end

                if ~scoutStopped
                    obj.startImagingEtaTimer();

                    for index = 1:numel(preflight.zPositions)
                        if obj.Ports.stageLaser.isStopRequested()
                            result.status = "stopped";
                            break;
                        end

                        target = struct('x', preflight.x, 'y', preflight.y, 'z', preflight.zPositions(index));
                        obj.updateImagingProgress(index, numel(preflight.zPositions), target, "Moving");
                        [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                            obj.Model.State, target, preflight.motion, moveOptions);
                        if wasStopped || obj.Ports.stageLaser.isStopRequested()
                            result.status = "stopped";
                            break;
                        end

                        obj.updateImagingProgress(index, numel(preflight.zPositions), target, "Settling");
                        obj.Ports.stageLaser.pauseWithUi(preflight.settlingTime);
                        if obj.Ports.stageLaser.isStopRequested()
                            result.status = "stopped";
                            break;
                        end

                        obj.updateImagingProgress(index, numel(preflight.zPositions), target, "Capturing");
                        captureOptions = struct( ...
                            'shouldStopFcn', @() obj.Ports.stageLaser.isStopRequested(), ...
                            'yieldFcn', @() obj.Ports.stageLaser.yieldWithLivePosition(), ...
                            'pollTimeoutMs', 100);
                        [obj.Model.State.flir, frame, info, wasStopped] = obj.Model.Services.flir.grabFrame( ...
                            obj.Model.State.flir, preflight.captureTimeoutMs, captureOptions);
                        if wasStopped || obj.Ports.stageLaser.isStopRequested()
                            result.status = "stopped";
                            break;
                        end
                        stackPage = numel(metadataRows) + 1;
                        lw_write_imaging_stack_frame(frame, preflight.stackFile, stackPage);

                        metadataRows(end + 1) = lw_imaging_metadata_row(index, target, ...
                            obj.Ports.stageYToDisplay(target.y), ...
                            preflight.stackFileName, stackPage, info, actualExposureUs, actualGain, ...
                            obj.Ports.carbide.cachedCarbidePulseEnergyMicroJoules(), preflight.slmSnapshot); %#ok<AGROW>
                        lw_write_imaging_metadata(metadataRows, metadataFile);
                        obj.showImagingFrame(frame, sprintf('Z %.3f mm | %d/%d', target.z, index, numel(preflight.zPositions)));
                        obj.updateImagingProgress(index, numel(preflight.zPositions), target, "Captured");
                    end
                end
            catch ME
                if acquisitionStarted
                    try
                        obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
                    catch
                    end
                end
                if ~isempty(metadataRows)
                    lw_write_imaging_metadata(metadataRows, metadataFile);
                end
                rethrow(ME);
            end

            if acquisitionStarted
                obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
            end
            result.capturedCount = numel(metadataRows);
            if obj.Model.State.stopRequested
                result.status = "stopped";
            end
        end

        function tf = imagingAutoExposureEnabled(~, preflight)
            tf = isfield(preflight, 'autoExposure') && isstruct(preflight.autoExposure) && ...
                isfield(preflight.autoExposure, 'enabled') && logical(preflight.autoExposure.enabled);
        end

        function [actualExposureUs, scoutResult, acquisitionStarted, wasStopped] = ...
                runImagingAutoExposureScout(obj, preflight, startingExposureUs, acquisitionStarted, moveOptions)
            options = preflight.autoExposure;
            zSamples = lw_imaging_auto_exposure_z_samples(preflight.zPositions, options.sampleCount);
            scoutFile = fullfile(preflight.runFolder, 'auto_exposure_scout.csv');
            scoutRows = lw_empty_imaging_auto_exposure_scout_rows();
            scoutExposureUs = double(startingExposureUs);
            actualExposureUs = scoutExposureUs;
            wasStopped = false;
            maxRetries = max(1, round(double(options.maxRetries)));
            scoutResult = struct( ...
                'status', "not_run", ...
                'requestedSampleCount', options.sampleCount, ...
                'actualSampleCount', numel(zSamples), ...
                'scoutCount', 0, ...
                'scoutFile', string(scoutFile), ...
                'scoutExposureUs', scoutExposureUs, ...
                'finalExposureUs', actualExposureUs, ...
                'exposureLimitUs', NaN, ...
                'maxIntensity', NaN, ...
                'fullScale', NaN, ...
                'brightestZ', NaN);

            obj.Ports.logMessage(sprintf('Auto exposure scout started: %d sampled Z plane(s), target %.0f%% of no-clip exposure.', ...
                numel(zSamples), 100 * options.safetyFactor));

            for attempt = 1:maxRetries
                [attemptRows, attemptResult, wasStopped] = obj.captureImagingAutoExposureAttempt( ...
                    preflight, zSamples, scoutExposureUs, attempt, moveOptions);
                scoutRows = [scoutRows, attemptRows]; %#ok<AGROW>
                lw_write_imaging_auto_exposure_scout_rows(scoutRows, scoutFile);
                scoutResult.scoutCount = numel(scoutRows);
                scoutResult.scoutExposureUs = scoutExposureUs;
                scoutResult.maxIntensity = attemptResult.maxIntensity;
                scoutResult.fullScale = attemptResult.fullScale;
                scoutResult.brightestZ = attemptResult.brightestZ;

                if wasStopped || obj.Ports.stageLaser.isStopRequested()
                    scoutResult.status = "stopped";
                    return;
                end

                if ~isfinite(attemptResult.maxIntensity) || attemptResult.maxIntensity <= 0
                    scoutResult.status = "no_signal";
                    scoutResult.finalExposureUs = actualExposureUs;
                    obj.Ports.logMessage('Auto exposure scout found no positive signal; keeping current FLIR exposure.');
                    return;
                end

                if attemptResult.isSaturated
                    nextExposureUs = scoutExposureUs * 0.5;
                    [actualExposureUs, acquisitionStarted] = obj.restartFlirAcquisitionWithExposure( ...
                        nextExposureUs, acquisitionStarted);
                    if actualExposureUs >= scoutExposureUs * 0.999
                        scoutResult.status = "saturated_at_minimum";
                        scoutResult.finalExposureUs = actualExposureUs;
                        obj.Ports.logMessage(sprintf(['Auto exposure scout is still saturated at %.6g us, ', ...
                            'and the camera did not allow a lower exposure.'], actualExposureUs));
                        return;
                    end
                    scoutExposureUs = actualExposureUs;
                    obj.Ports.logMessage(sprintf('Auto exposure scout saturated; retrying at %.6g us.', scoutExposureUs));
                    continue;
                end

                exposureLimitUs = scoutExposureUs * attemptResult.fullScale / attemptResult.maxIntensity;
                requestedFinalExposureUs = options.safetyFactor * exposureLimitUs;
                [actualExposureUs, acquisitionStarted] = obj.restartFlirAcquisitionWithExposure( ...
                    requestedFinalExposureUs, acquisitionStarted);
                scoutResult.status = "selected";
                scoutResult.exposureLimitUs = exposureLimitUs;
                scoutResult.finalExposureUs = actualExposureUs;
                obj.Model.Ui.FlirExposureField.Value = actualExposureUs;
                obj.Ports.logMessage(sprintf(['Auto exposure selected %.6g us from scout max %.6g / %.6g ', ...
                    'at Z %.3f mm (%.0f%% target).'], ...
                    actualExposureUs, attemptResult.maxIntensity, attemptResult.fullScale, ...
                    attemptResult.brightestZ, 100 * options.safetyFactor));
                return;
            end

            scoutResult.status = "max_retries";
            scoutResult.finalExposureUs = actualExposureUs;
            obj.Ports.logMessage(sprintf('Auto exposure scout reached %d retry attempt(s); keeping %.6g us.', ...
                maxRetries, actualExposureUs));
        end

        function [actualExposureUs, acquisitionStarted] = restartFlirAcquisitionWithExposure(obj, ...
                requestedExposureUs, acquisitionStarted)
            if acquisitionStarted
                obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
            end
            [obj.Model.State.flir, actualExposureUs] = obj.Model.Services.flir.setExposure( ...
                obj.Model.State.flir, requestedExposureUs);
            obj.Model.Ui.FlirExposureField.Value = actualExposureUs;
            obj.Ports.flir.syncFlirLiveWindowFieldsFromMain();
            obj.Model.State.flir = obj.Model.Services.flir.startAcquisition(obj.Model.State.flir);
            acquisitionStarted = true;
        end

        function [rows, attemptResult, wasStopped] = captureImagingAutoExposureAttempt(obj, ...
                preflight, zSamples, exposureUs, attempt, moveOptions)
            rows = lw_empty_imaging_auto_exposure_scout_rows();
            wasStopped = false;
            attemptResult = struct( ...
                'maxIntensity', NaN, ...
                'fullScale', NaN, ...
                'brightestZ', NaN, ...
                'isSaturated', false);
            captureOptions = struct( ...
                'shouldStopFcn', @() obj.Ports.stageLaser.isStopRequested(), ...
                'yieldFcn', @() obj.Ports.stageLaser.yieldWithLivePosition(), ...
                'pollTimeoutMs', 100);

            for sampleIndex = 1:numel(zSamples)
                if obj.Ports.stageLaser.isStopRequested()
                    wasStopped = true;
                    return;
                end

                target = struct('x', preflight.x, 'y', preflight.y, 'z', zSamples(sampleIndex));
                obj.updateImagingAutoExposureProgress(sampleIndex, numel(zSamples), target, ...
                    sprintf('Scout attempt %d moving', attempt));
                [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                    obj.Model.State, target, preflight.motion, moveOptions);
                if wasStopped || obj.Ports.stageLaser.isStopRequested()
                    wasStopped = true;
                    return;
                end

                obj.updateImagingAutoExposureProgress(sampleIndex, numel(zSamples), target, ...
                    sprintf('Scout attempt %d settling', attempt));
                obj.Ports.stageLaser.pauseWithUi(preflight.settlingTime);
                if obj.Ports.stageLaser.isStopRequested()
                    wasStopped = true;
                    return;
                end

                obj.updateImagingAutoExposureProgress(sampleIndex, numel(zSamples), target, ...
                    sprintf('Scout attempt %d capturing', attempt));
                [obj.Model.State.flir, frame, info, wasStopped] = obj.Model.Services.flir.grabFrame( ...
                    obj.Model.State.flir, preflight.captureTimeoutMs, captureOptions);
                if wasStopped || obj.Ports.stageLaser.isStopRequested()
                    wasStopped = true;
                    return;
                end

                stats = lw_imaging_frame_exposure_stats(frame, info);
                rows(end + 1) = lw_imaging_auto_exposure_scout_row( ...
                    attempt, sampleIndex, numel(zSamples), target, ...
                    obj.Ports.stageYToDisplay(target.y), exposureUs, stats, info); %#ok<AGROW>
                if ~isfinite(attemptResult.maxIntensity) || stats.maxIntensity > attemptResult.maxIntensity
                    attemptResult.maxIntensity = stats.maxIntensity;
                    attemptResult.fullScale = stats.fullScale;
                    attemptResult.brightestZ = target.z;
                end
                attemptResult.isSaturated = attemptResult.isSaturated || stats.isSaturated;

                obj.showImagingFrame(frame, sprintf('Auto exposure scout Z %.3f | max %.0f / %.0f', ...
                    target.z, stats.maxIntensity, stats.fullScale));
                obj.updateImagingAutoExposureProgress(sampleIndex, numel(zSamples), target, ...
                    sprintf('Scout attempt %d captured', attempt));
            end
        end

        function updateImagingAutoExposureProgress(obj, index, total, target, phase)
            obj.Model.ImagingProgressText = sprintf('Scout %d / %d', index, total);
            obj.Model.ImagingCurrentText = sprintf('Auto exposure | X %.3f | Y %.3f | Z %.3f | %s', ...
                target.x, obj.Ports.stageYToDisplay(target.y), target.z, char(phase));
            obj.Model.State.currentPosition = target;
            obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
            obj.Ports.syncPositionFields();
            obj.syncImagingStatus();
            obj.Ports.trajectory.syncPreviewCurrentPosition();
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function complete3DImagingExecution(obj, result)
            switch string(result.status)
                case "stopped"
                    obj.Model.ImagingProgressText = sprintf('%d / %d (stopped)', result.capturedCount, result.totalCount);
                    obj.Model.ImagingCurrentText = sprintf('Stopped after %d frame(s)', result.capturedCount);
                    obj.Ports.logMessage(sprintf('3D imaging stopped after %d frame(s).', result.capturedCount));
                otherwise
                    obj.Model.ImagingProgressText = obj.formatImagingProgressText(result.totalCount, result.totalCount, "Captured");
                    obj.Model.ImagingCurrentText = sprintf('Finished: %d frame(s)', result.capturedCount);
                    obj.Ports.logMessage(sprintf('3D imaging finished: %d frame(s).', result.capturedCount));
            end
            obj.Model.Ui.ImagingOutputField.Value = char(result.stackFile);
            if result.capturedCount > 0
                obj.Ports.logMessage(sprintf('3D imaging TIFF stack saved: %s', char(result.stackFile)));
                obj.Ports.logMessage(sprintf('3D imaging metadata saved: %s', char(result.metadataFile)));
            end
            if isfield(result, 'autoExposureEnabled') && logical(result.autoExposureEnabled)
                obj.Ports.logMessage(sprintf('3D imaging auto exposure used %.6g us after %d scout frame(s).', ...
                    result.actualExposureUs, result.autoExposureScoutCount));
                if strlength(string(result.autoExposureScoutFile)) > 0
                    obj.Ports.logMessage(sprintf('3D imaging auto exposure scout saved: %s', char(result.autoExposureScoutFile)));
                end
            end
            obj.finish3DImagingCleanup();
        end

        function finish3DImagingCleanup(obj)
            try
                if isfield(obj.Model.State, 'flir') && isstruct(obj.Model.State.flir)
                    obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
                end
            catch
            end
            obj.Model.State.isBusy = false;
            obj.Model.State.pauseRequested = false;
            obj.Model.State.isPaused = false;
            obj.Model.State.resumeContext = [];
            obj.Model.ImagingRunActive = false;
            try
                if obj.Ports.stageLaser.areStagesConnected()
                    obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
                    obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
                end
            catch
            end
            obj.Ports.syncAll();
        end

        function syncImagingStatus(obj)
            if ~isfield(obj.Model.Ui, 'ImagingProgressField')
                return;
            end
            obj.Model.Ui.ImagingProgressField.Value = char(obj.Model.ImagingProgressText);
            obj.Model.Ui.ImagingCurrentField.Value = char(obj.Model.ImagingCurrentText);
        end

        function updateImagingProgress(obj, index, total, target, phase)
            obj.Model.ImagingProgressText = obj.formatImagingProgressText(index, total, phase);
            obj.Model.ImagingCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | %s', ...
                target.x, obj.Ports.stageYToDisplay(target.y), target.z, char(phase));
            if string(phase) ~= "Moving"
                obj.Model.State.currentPosition = target;
                obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
            end
            obj.Ports.syncPositionFields();
            obj.syncImagingStatus();
            obj.Ports.trajectory.syncPreviewCurrentPosition();
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function startImagingEtaTimer(obj)
            obj.Model.ImagingEtaStartTic = obj.Model.Services.clock.tic();
        end

        function textValue = formatImagingProgressText(obj, index, total, phase)
            if total <= 0
                textValue = '0 / 0';
                return;
            end

            index = max(0, min(round(double(index)), total));
            phaseFraction = 0;
            switch string(phase)
                case "Moving"
                    phaseFraction = 0.15;
                case "Settling"
                    phaseFraction = 0.45;
                case "Capturing"
                    phaseFraction = 0.75;
                case "Captured"
                    phaseFraction = 1;
            end

            completedUnits = max(index - 1, 0) + phaseFraction;
            if index == 0
                completedUnits = 0;
            elseif string(phase) == "Captured"
                completedUnits = index;
            end
            percentValue = 100 * min(max(completedUnits / total, 0), 1);
            textValue = sprintf('%d / %d (%.0f%%)%s', index, total, percentValue, ...
                char(lw_format_eta_suffix(obj.Model.ImagingEtaStartTic, 0, completedUnits, total)));
        end

        function showImagingFrame(obj, frame, titleText)
            if isempty(frame) || ~isfield(obj.Model.Ui, 'ImagingAxes') || ~isvalid(obj.Model.Ui.ImagingAxes)
                return;
            end
            if ismatrix(frame)
                imagesc(obj.Model.Ui.ImagingAxes, frame);
                colormap(obj.Model.Ui.ImagingAxes, gray(256));
            else
                image(obj.Model.Ui.ImagingAxes, frame);
            end
            axis(obj.Model.Ui.ImagingAxes, 'image');
            obj.Model.Ui.ImagingAxes.XTick = [];
            obj.Model.Ui.ImagingAxes.YTick = [];
            title(obj.Model.Ui.ImagingAxes, titleText);
            obj.Model.Services.ui.drawnow('limitrate');
        end

    end
end
