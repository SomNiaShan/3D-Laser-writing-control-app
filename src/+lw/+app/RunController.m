classdef RunController < handle
    %RUNCONTROLLER Orchestrate preflight, run modes, pause/resume, and recovery.

    properties (SetAccess = private)
        Model
        Ports
    end

    methods
        function obj = RunController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("RunController", ports, [ ...
                "carbide", "displayYToStage", "logMessage", "projectRoot", "runUiAction", ...
                "stageLaser", "stageYToDisplay", "syncAll", "syncPositionFields", ...
                "trajectory", "validateTargetForUi"]);
        end

        function onStartRun(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused
                return;
            end
            obj.Ports.runUiAction(@() obj.startRunImpl(), 'Run failed');
        end

        function onPauseResumeRun(obj, ~, ~)
            if obj.Model.State.isPaused
                if obj.Model.State.isBusy || obj.Model.PausedManualMotionActive || isempty(obj.Model.State.resumeContext)
                    return;
                end
                obj.Ports.runUiAction(@() obj.resumeRunImpl(), 'Resume failed');
                return;
            end

            if ~obj.Model.State.isBusy || obj.Model.State.pauseRequested
                return;
            end
            if obj.selectedRunMode() == "Stream Mode"
                obj.Ports.logMessage('Pause is not available in Stream Mode; use STOP for a safe shutdown.');
                obj.Ports.syncAll();
                return;
            end

            obj.Model.State.pauseRequested = true;
            obj.Model.RunCurrentText = obj.formatRunStatusWithCurrentPosition("Pause requested - finishing current step");
            obj.Ports.logMessage('Pause requested; finishing the current safe step before pausing.');
            obj.Ports.syncAll();
        end

        function onGoToFirstPoint(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused
                return;
            end
            obj.Ports.runUiAction(@() obj.goToFirstPointImpl(), 'Go to First Point failed');
        end

        function onCheckBounds(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused
                return;
            end
            obj.Ports.runUiAction(@() obj.checkBoundsImpl(), 'Check Bounds failed');
        end

        function startRunImpl(obj)
            runMode = obj.selectedRunMode();
            switch runMode
                case "Point Mode"
                    preflight = obj.buildPointRunPreflight();
                case "Stream Mode"
                    preflight = obj.buildPulseRunPreflight();
                case "Z Sweep Mode"
                    preflight = obj.buildZSweepRunPreflight();
                case "Cut Plan Mode"
                    preflight = obj.buildCutPlanRunPreflight();
                otherwise
                    error('Unsupported run mode: %s', char(runMode));
            end
            preflight.runMode = runMode;

            choice = string(obj.Model.Services.dialog.confirm( ...
                obj.Model.Figure, preflight.summaryText, 'Run Preflight', ...
                'Options', {'Start', 'Cancel'}, ...
                'DefaultOption', 'Start', ...
                'CancelOption', 'Cancel', ...
                'Icon', 'question'));
            if choice ~= "Start"
                obj.Model.RunProgressText = "Preflight cancelled";
                obj.Model.RunCurrentText = obj.formatRunStatusWithCurrentPosition("Preflight cancelled");
                obj.Ports.logMessage('Run cancelled at preflight.');
                return;
            end

            try
                obj.Model.RunLog = lw_run_log('begin', obj.Model.RunLog, preflight, ...
                    obj.Model.State, obj.Model.Config, obj.Ports.projectRoot);
                obj.Ports.logMessage(sprintf('Run log folder: %s', char(obj.Model.RunLog.folder)));
            catch ME
                obj.Model.RunLog = lw_run_log('empty');
                obj.Ports.logMessage(sprintf('Run log unavailable: %s', compactErrorMessage(ME)));
            end
            obj.beginRunExecution(preflight);

            try
                runResult = obj.executeRunSnapshot(runMode, preflight, []);
                obj.completeRunExecution(runMode, runResult);
            catch ME
                obj.finishRunCleanup(false);
                try
                    obj.Model.RunLog = lw_run_log('error', obj.Model.RunLog, ME, true, ...
                        obj.makeRunResult("error", obj.localCurrentRunTarget(), []), obj.Model.State, obj.Model.Config);
                catch
                end
                rethrow(ME);
            end
        end

        function resumeRunImpl(obj)
            if ~obj.Model.State.isPaused || isempty(obj.Model.State.resumeContext)
                error('No paused run is available to resume.');
            end

            resumeContext = obj.Model.State.resumeContext;
            runMode = string(resumeContext.runMode);
            preflight = resumeContext.preflight;

            obj.Model.State.stopRequested = false;
            obj.Model.State.pauseRequested = false;
            obj.Model.State.isPaused = false;
            obj.Model.State.isBusy = true;
            obj.Model.RunCurrentText = obj.formatRunTargetStatus(resumeContext.returnTarget, "Returning to pause point");
            obj.Ports.logMessage('Resume requested; returning to the saved pause point.');
            obj.Ports.syncAll();

            try
                obj.Ports.stageLaser.forceLaserSafeOff();
                obj.Ports.validateTargetForUi(resumeContext.returnTarget, 'Resume return');
                moveOptions = struct( ...
                    'shouldStopFcn', @() obj.Ports.stageLaser.isStopRequested(), ...
                    'yieldFcn', @() obj.Ports.stageLaser.yieldWithLivePosition(), ...
                    'pollIntervalSeconds', 0.02);
                [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                    obj.Model.State, resumeContext.returnTarget, obj.resumeReturnMotion(resumeContext), moveOptions);
                obj.Ports.stageLaser.forceLaserSafeOff();

                if wasStopped || obj.Model.State.stopRequested
                    runResult = obj.makeRunResult("stopped", obj.localCurrentRunTarget(), []);
                else
                    obj.startRunEtaTimer(obj.runResumeCompletedUnits(resumeContext));
                    runResult = obj.executeRunSnapshot(runMode, preflight, resumeContext);
                end
                obj.completeRunExecution(runMode, runResult);
            catch ME
                obj.Model.State.isBusy = false;
                obj.Model.State.pauseRequested = false;
                if obj.Model.State.stopRequested
                    obj.Model.State.isPaused = false;
                    obj.Model.State.resumeContext = [];
                else
                    obj.Model.State.isPaused = true;
                    obj.Model.State.resumeContext = resumeContext;
                end
                obj.Ports.stageLaser.forceLaserSafeOff();
                obj.Ports.syncAll();
                try
                    obj.Model.RunLog = lw_run_log('error', obj.Model.RunLog, ME, ~(obj.Model.State.isPaused && ~obj.Model.State.stopRequested), ...
                        obj.makeRunResult("error", obj.localCurrentRunTarget(), []), obj.Model.State, obj.Model.Config);
                catch
                end
                rethrow(ME);
            end
        end

        function beginRunExecution(obj, preflight)
            obj.Model.State.stopRequested = false;
            obj.Model.State.pauseRequested = false;
            obj.Model.State.isPaused = false;
            obj.Model.State.resumeContext = [];
            obj.Model.State.isBusy = true;
            obj.Model.RunEtaStartTic = [];
            obj.Model.RunEtaBaselineUnits = 0;
            obj.Model.RunProgressText = obj.formatRunProgressText(0, obj.runProgressTotal(preflight), "Preparing");
            obj.Model.RunCurrentText = "Preparing";
            obj.Ports.syncAll();
            obj.Ports.carbide.logCarbideRunStartSnapshot();
            obj.startRunEtaTimer(0);
        end

        function runResult = executeRunSnapshot(obj, runMode, preflight, resumeContext)
            options = struct();
            options.shouldStopFcn = @() obj.Ports.stageLaser.isStopRequested();
            options.pauseRequestedFcn = @() obj.Ports.stageLaser.isPauseRequested();
            options.progressFcn = @obj.updateRunProgress;
            options.yieldFcn = @() obj.Ports.stageLaser.yieldWithLivePosition();

            switch runMode
                case "Point Mode"
                    if isempty(resumeContext)
                        options.startIndex = 1;
                        obj.Ports.logMessage(sprintf('Point mode started with %d points.', numel(preflight.trajectory.x)));
                    else
                        options.startIndex = resumeContext.nextPointIndex;
                        obj.Ports.logMessage(sprintf('Point mode resumed at point %d of %d.', ...
                            options.startIndex, numel(preflight.trajectory.x)));
                    end
                    options.pauseSeconds = preflight.pauseSeconds;
                    options.exposureTimeSeconds = preflight.exposureTimeSeconds;
                    options.motion = preflight.motion;
                    options.laserStateFcn = @(isOn) obj.Ports.stageLaser.setLaserState(isOn);
                    [obj.Model.State, pointResult] = obj.Model.Services.execution.runPoint( ...
                        obj.Model.State, obj.Model.Config, preflight.trajectory, options);
                    runResult = obj.runResultFromPoint(preflight, pointResult);

                case "Stream Mode"
                    obj.Ports.logMessage(sprintf('Stream mode started with %d points at %.3f mm/s.', ...
                        numel(preflight.trajectory.x), preflight.pulseSpeedMmPerSecond));
                    options.motion = preflight.motion;
                    options.targetSpeedMmPerSecond = preflight.pulseSpeedMmPerSecond;
                    options.powerPercent = preflight.powerPercent;
                    options.ttlGateWidthUs = preflight.ttlGateWidthUs;
                    options.pulseTimesSeconds = preflight.pulseTimesSeconds;
                    obj.Model.State = obj.Model.Services.execution.runStream( ...
                        obj.Model.State, obj.Model.Config, preflight.trajectory, options);
                    runResult = obj.makeRunResult(ternary(obj.Model.State.stopRequested, "stopped", "finished"), obj.localCurrentRunTarget(), []);

                case "Z Sweep Mode"
                    options.laserStateFcn = @(isOn) obj.Ports.stageLaser.setLaserState(isOn);
                    runResult = obj.runZSweepJobs(preflight, options, resumeContext);

                case "Cut Plan Mode"
                    if isempty(resumeContext)
                        options.startCutIndex = 1;
                        obj.Ports.logMessage(sprintf('Cut Plan Mode started with %d cut group(s).', preflight.progressTotal));
                    else
                        options.startCutIndex = resumeContext.nextCutIndex;
                        obj.Ports.logMessage(sprintf('Cut Plan Mode resumed at cut group %d of %d.', ...
                            options.startCutIndex, preflight.progressTotal));
                    end
                    options.motion = preflight.motion;
                    options.laserStateFcn = @(isOn) obj.Ports.stageLaser.setLaserState(isOn);
                    [obj.Model.State, cutResult] = obj.Model.Services.execution.runCutPlan( ...
                        obj.Model.State, obj.Model.Config, preflight.trajectory, options);
                    runResult = obj.runResultFromCutPlan(preflight, cutResult);

                otherwise
                    error('Unsupported run mode: %s', char(runMode));
            end
        end

        function runResult = runResultFromPoint(obj, preflight, pointResult)
            if pointResult.status == "paused"
                resumeContext = struct( ...
                    'kind', "point", ...
                    'runMode', "Point Mode", ...
                    'preflight', preflight, ...
                    'nextPointIndex', pointResult.nextPointIndex, ...
                    'returnTarget', pointResult.returnTarget);
                runResult = obj.makeRunResult("paused", pointResult.returnTarget, resumeContext);
                return;
            end
            runResult = obj.makeRunResult(pointResult.status, pointResult.returnTarget, []);
        end

        function runResult = runResultFromCutPlan(obj, preflight, cutResult)
            if cutResult.status == "paused"
                resumeContext = struct( ...
                    'kind', "cutPlan", ...
                    'runMode', "Cut Plan Mode", ...
                    'preflight', preflight, ...
                    'nextCutIndex', cutResult.nextCutIndex, ...
                    'returnTarget', cutResult.returnTarget);
                runResult = obj.makeRunResult("paused", cutResult.returnTarget, resumeContext);
                return;
            end
            runResult = obj.makeRunResult(cutResult.status, cutResult.returnTarget, []);
        end

        function runResult = runZSweepJobs(obj, preflight, options, resumeContext)
            jobs = preflight.sweepJobs;
            jobCount = numel(jobs);
            startJobIndex = 1;
            startStepIndex = 1;
            progressOffset = 0;
            recoveryLimit = obj.zSweepRecoveryAttemptLimit();
            if ~isempty(resumeContext)
                startJobIndex = resumeContext.jobIndex;
                startStepIndex = resumeContext.stepIndex;
                progressOffset = resumeContext.progressOffset;
            end

            for jobIndex = startJobIndex:jobCount
                recoveryAttempt = 0;
                while true
                    if options.shouldStopFcn()
                        runResult = obj.makeRunResult("stopped", obj.localCurrentRunTarget(), []);
                        return;
                    end

                    job = jobs(jobIndex);
                    obj.logZSweepJobStart(preflight, job, jobIndex, jobCount, startStepIndex);

                    runOptions = options;
                    runOptions.progressFcn = @(index, total, target, phase) ...
                        obj.updateRunProgress(progressOffset + index, preflight.progressTotal, target, phase);
                    runOptions.startStepIndex = startStepIndex;
                    [obj.Model.State, sweepResult] = obj.Model.Services.execution.runZSweep( ...
                        obj.Model.State, obj.Model.Config, job.sweep, runOptions);

                    if sweepResult.status ~= "hardware_error"
                        break;
                    end

                    recoveryAttempt = recoveryAttempt + 1;
                    resumeContext = obj.zSweepResumeContext( ...
                        preflight, jobIndex, sweepResult.nextStepIndex, progressOffset, sweepResult.returnTarget);
                    didRecover = obj.recoverZSweepHardwareError( ...
                        resumeContext, sweepResult.errorMessage, recoveryAttempt, recoveryLimit);
                    if didRecover
                        startStepIndex = sweepResult.nextStepIndex;
                        continue;
                    end

                    if obj.Model.State.stopRequested || options.shouldStopFcn()
                        runResult = obj.makeRunResult("stopped", obj.localCurrentRunTarget(), []);
                    else
                        obj.Ports.logMessage('Z Sweep paused after a stage connection error. Reconnect stages, then press Resume.');
                        runResult = obj.makeRunResult("paused", resumeContext.returnTarget, resumeContext);
                    end
                    return;
                end

                if sweepResult.status == "paused"
                    resumeContext = obj.zSweepResumeContext( ...
                        preflight, jobIndex, sweepResult.nextStepIndex, progressOffset, sweepResult.returnTarget);
                    runResult = obj.makeRunResult("paused", sweepResult.returnTarget, resumeContext);
                    return;
                end
                if sweepResult.status == "stopped" || obj.Model.State.stopRequested || options.shouldStopFcn()
                    runResult = obj.makeRunResult("stopped", sweepResult.returnTarget, []);
                    return;
                end

                progressOffset = progressOffset + zSweepProgressTotal(job.sweep);
                if jobIndex < jobCount && options.pauseRequestedFcn()
                    resumeContext = obj.zSweepResumeContext( ...
                        preflight, jobIndex + 1, 1, progressOffset, sweepResult.returnTarget);
                    runResult = obj.makeRunResult("paused", sweepResult.returnTarget, resumeContext);
                    return;
                end
                startStepIndex = 1;
            end

            runResult = obj.makeRunResult("finished", obj.localCurrentRunTarget(), []);
        end

        function logZSweepJobStart(obj, preflight, job, jobIndex, jobCount, startStepIndex)
            runSweep = job.sweep;
            resumeText = "";
            if startStepIndex > 1
                resumeText = sprintf(' resuming at step %d,', startStepIndex);
            end
            if isfield(preflight, 'matrix')
                matrix = preflight.matrix;
                blockLogText = "";
                if strlength(job.blockText) > 0
                    blockLogText = sprintf(' block %d/%d (%s),', ...
                        job.blockIndex, matrix.block.count, char(job.blockText));
                end
                obj.Ports.logMessage(sprintf(['Z Sweep matrix %d/%d:%s%s X %.3f, Y %.3f, ', ...
                    '%s=%s, %s=%s, power %.2f %%, sweep %.3f mm/s, return %.3f mm/s, repeat %d, %s.'], ...
                    jobIndex, jobCount, ...
                    char(blockLogText), char(resumeText), ...
                    runSweep.x, runSweep.displayY, ...
                    char(matrix.xParameter), char(job.xValueText), ...
                    char(matrix.yParameter), char(job.yValueText), ...
                    runSweep.powerPercent, runSweep.sweepSpeedMmPerSecond, ...
                    runSweep.returnSpeedMmPerSecond, runSweep.repeatCount, ...
                    char(runSweep.exposureDirection)));
            else
                obj.Ports.logMessage(sprintf(['Z Sweep mode%s started: X %.3f, Y %.3f, ', ...
                    'power %.2f %%, sweep %.3f mm/s, return %.3f mm/s, repeat %d, %s.'], ...
                    char(resumeText), runSweep.x, runSweep.displayY, ...
                    runSweep.powerPercent, runSweep.sweepSpeedMmPerSecond, ...
                    runSweep.returnSpeedMmPerSecond, runSweep.repeatCount, ...
                    char(runSweep.exposureDirection)));
            end
        end

        function context = zSweepResumeContext(~, preflight, jobIndex, stepIndex, progressOffset, returnTarget)
            context = struct( ...
                'kind', "zSweep", ...
                'runMode', "Z Sweep Mode", ...
                'preflight', preflight, ...
                'jobIndex', jobIndex, ...
                'stepIndex', stepIndex, ...
                'progressOffset', progressOffset, ...
                'returnTarget', returnTarget);
        end

        function count = zSweepRecoveryAttemptLimit(obj)
            count = 3;
            if isfield(obj.Model.Config, 'execution') && isfield(obj.Model.Config.execution, 'zSweepRecoveryAttempts')
                count = max(0, round(double(obj.Model.Config.execution.zSweepRecoveryAttempts)));
            end
        end

        function didRecover = recoverZSweepHardwareError(obj, resumeContext, errorMessage, recoveryAttempt, recoveryLimit)
            didRecover = false;
            if recoveryAttempt > recoveryLimit
                obj.Ports.logMessage(sprintf('Zaber recovery limit reached after %d attempt(s): %s', ...
                    recoveryLimit, compactErrorMessage(errorMessage)));
                obj.clearStageConnectionHandles();
                obj.Ports.stageLaser.forceLaserSafeOff();
                return;
            end

            obj.Model.RunCurrentText = obj.formatRunTargetStatus(resumeContext.returnTarget, ...
                sprintf('Recovering Zaber connection %d/%d', recoveryAttempt, recoveryLimit));
            obj.Ports.logMessage(sprintf('Zaber connection error during Z Sweep step %d; recovery attempt %d/%d: %s', ...
                resumeContext.stepIndex, recoveryAttempt, recoveryLimit, compactErrorMessage(errorMessage)));
            obj.Ports.stageLaser.forceLaserSafeOff();
            obj.clearStageConnectionHandles();
            obj.Ports.syncAll();

            if ~obj.reconnectStagesForRecovery()
                return;
            end

            try
                obj.Ports.stageLaser.forceLaserSafeOff();
                obj.Model.Services.stage.stop(obj.Model.State);
                obj.Ports.stageLaser.pauseWithUi(0.2);
                obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
                obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();

                obj.Ports.validateTargetForUi(resumeContext.returnTarget, 'Z Sweep recovery return');
                obj.Model.RunCurrentText = obj.formatRunTargetStatus(resumeContext.returnTarget, ...
                    "Recovering - returning to step start");
                obj.Ports.syncAll();

                moveOptions = struct( ...
                    'shouldStopFcn', @() obj.Ports.stageLaser.isStopRequested(), ...
                    'yieldFcn', @() obj.Ports.stageLaser.yieldWithLivePosition(), ...
                    'pollIntervalSeconds', 0.05);
                [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                    obj.Model.State, resumeContext.returnTarget, obj.resumeReturnMotion(resumeContext), moveOptions);
                obj.Ports.stageLaser.forceLaserSafeOff();

                if wasStopped || obj.Model.State.stopRequested
                    obj.Ports.logMessage('Z Sweep recovery stopped by user.');
                    return;
                end

                obj.Ports.logMessage(sprintf('Zaber recovery complete; retrying Z Sweep step %d.', ...
                    resumeContext.stepIndex));
                didRecover = true;
            catch ME
                obj.Ports.stageLaser.forceLaserSafeOff();
                if lw_is_recoverable_zaber_error(ME)
                    obj.Ports.logMessage(sprintf('Zaber recovery return move failed: %s', compactErrorMessage(ME)));
                    obj.clearStageConnectionHandles();
                    return;
                end
                rethrow(ME);
            end
        end

        function connected = reconnectStagesForRecovery(obj)
            connected = false;
            maxConnectAttempts = 3;
            for attempt = 1:maxConnectAttempts
                if obj.Model.State.stopRequested
                    return;
                end
                try
                    obj.Model.RunCurrentText = sprintf('Reconnecting stages %d/%d', attempt, maxConnectAttempts);
                    obj.Ports.syncAll();
                    obj.Model.State = obj.Model.Services.stage.connect(obj.Model.State, obj.Model.Config);
                    obj.Ports.stageLaser.startPositionTimer();
                    connected = true;
                    obj.Ports.logMessage(sprintf('Stages reconnected on %s.', obj.Model.Config.stage.comPort));
                    return;
                catch ME
                    obj.clearStageConnectionHandles();
                    obj.Ports.logMessage(sprintf('Stage reconnect attempt %d/%d failed: %s', ...
                        attempt, maxConnectAttempts, compactErrorMessage(ME)));
                    obj.Ports.stageLaser.pauseWithUi(1.0);
                end
            end
        end

        function clearStageConnectionHandles(obj)
            obj.Ports.stageLaser.stopPositionTimer();
            try
                if isfield(obj.Model.State, 'conn') && ~isempty(obj.Model.State.conn)
                    obj.Model.State.conn.close();
                end
            catch
            end
            obj.Model.State.conn = [];
            obj.Model.State.devices = struct('x', [], 'y', [], 'z', []);
            obj.Model.State.axes = struct('x', [], 'y', [], 'z', []);
        end

        function completeRunExecution(obj, runMode, runResult)
            switch string(runResult.status)
                case "paused"
                    obj.Model.State.isPaused = true;
                    obj.Model.State.pauseRequested = false;
                    obj.Model.State.resumeContext = runResult.resumeContext;
                    obj.Model.RunCurrentText = obj.formatRunTargetStatus(runResult.returnTarget, "Paused");
                    obj.Model.RunProgressText = lw_progress_text_without_eta(obj.Model.RunProgressText);
                    obj.Ports.logMessage(sprintf('%s paused at a safe boundary.', char(runMode)));
                    obj.finishRunCleanup(true);
                    try
                        obj.Model.RunLog = lw_run_log('paused', obj.Model.RunLog, runMode, runResult, obj.Model.State, obj.Model.Config);
                    catch
                    end
                case "stopped"
                    obj.Model.State.isPaused = false;
                    obj.Model.State.pauseRequested = false;
                    obj.Model.State.resumeContext = [];
                    obj.Model.RunCurrentText = obj.formatRunStatusWithCurrentPosition("Stopped");
                    obj.Model.RunProgressText = lw_progress_text_without_eta(obj.Model.RunProgressText);
                    obj.Ports.logMessage(sprintf('%s stopped by user.', char(runMode)));
                    obj.finishRunCleanup(false);
                    try
                        obj.Model.RunLog = lw_run_log('finalize', obj.Model.RunLog, "stopped", runResult, obj.Model.State, obj.Model.Config, []);
                    catch
                    end
                otherwise
                    obj.Model.State.isPaused = false;
                    obj.Model.State.pauseRequested = false;
                    obj.Model.State.resumeContext = [];
                    obj.Model.RunCurrentText = "Finished";
                    obj.Ports.logMessage(sprintf('%s finished.', char(runMode)));
                    obj.finishRunCleanup(false);
                    obj.Ports.carbide.autoStandbyAfterFinishedRun();
                    try
                        obj.Model.RunLog = lw_run_log('finalize', obj.Model.RunLog, "finished", runResult, obj.Model.State, obj.Model.Config, []);
                    catch
                    end
            end
        end

        function result = makeRunResult(obj, status, returnTarget, resumeContext)
            if nargin < 3 || isempty(returnTarget)
                returnTarget = obj.localCurrentRunTarget();
            end
            if nargin < 4
                resumeContext = [];
            end
            result = struct( ...
                'status', string(status), ...
                'returnTarget', returnTarget, ...
                'resumeContext', resumeContext);
        end

        function target = localCurrentRunTarget(obj)
            target = obj.Model.State.currentPosition;
        end

        function startRunEtaTimer(obj, completedUnits)
            if nargin < 2 || isempty(completedUnits)
                completedUnits = 0;
            end
            obj.Model.RunEtaStartTic = obj.Model.Services.clock.tic();
            obj.Model.RunEtaBaselineUnits = max(0, double(completedUnits));
        end

        function completedUnits = runResumeCompletedUnits(~, resumeContext)
            completedUnits = 0;
            if isempty(resumeContext) || ~isstruct(resumeContext) || ~isfield(resumeContext, 'kind')
                return;
            end

            switch string(resumeContext.kind)
                case "point"
                    if isfield(resumeContext, 'nextPointIndex')
                        completedUnits = max(0, double(resumeContext.nextPointIndex) - 1);
                    end
                case "zSweep"
                    progressOffset = 0;
                    stepIndex = 1;
                    if isfield(resumeContext, 'progressOffset')
                        progressOffset = double(resumeContext.progressOffset);
                    end
                    if isfield(resumeContext, 'stepIndex')
                        stepIndex = double(resumeContext.stepIndex);
                    end
                    completedUnits = max(0, progressOffset + stepIndex - 1);
                case "cutPlan"
                    if isfield(resumeContext, 'nextCutIndex')
                        completedUnits = max(0, double(resumeContext.nextCutIndex) - 1);
                    end
            end
        end

        function total = runProgressTotal(~, preflight)
            if isfield(preflight, 'progressTotal')
                total = preflight.progressTotal;
            else
                total = numel(preflight.trajectory.x);
            end
        end

        function motion = resumeReturnMotion(obj, resumeContext)
            switch string(resumeContext.kind)
                case "point"
                    motion = resumeContext.preflight.motion;
                case "zSweep"
                    jobIndex = min(resumeContext.jobIndex, numel(resumeContext.preflight.sweepJobs));
                    motion = resumeContext.preflight.sweepJobs(jobIndex).sweep.preMoveMotion;
                case "cutPlan"
                    motion = resumeContext.preflight.motion;
                otherwise
                    motion = obj.Ports.stageLaser.readAbsoluteMotion();
            end
        end

        function finishRunCleanup(obj, keepPaused)
            if nargin < 2
                keepPaused = false;
            end
            obj.Ports.stageLaser.forceLaserSafeOff();
            obj.Model.State.isBusy = false;
            if ~keepPaused
                obj.Model.State.isPaused = false;
            end
            try
                if obj.Ports.stageLaser.areStagesConnected()
                    obj.Model.State.currentPosition = obj.Model.Services.stage.getPosition(obj.Model.State);
                    obj.Model.LastPositionRefreshTic = obj.Model.Services.clock.tic();
                end
            catch
            end

            if ~obj.Model.State.stopRequested && obj.Model.RunCurrentText == "Preparing"
                obj.Model.RunCurrentText = "Idle";
            end

            obj.Ports.syncAll();
        end

        function goToFirstPointImpl(obj)
            obj.requireTrajectoryLoaded();
            obj.Ports.stageLaser.requireStagesConnected();

            target = obj.firstRunTargetForCurrentMode();
            obj.Ports.validateTargetForUi(target, 'Go to First Point');
            obj.executeMotionTargetsNoLaser("Go to First Point", target, "Go to First Point");
        end

        function target = firstRunTargetForCurrentMode(obj)
            if obj.selectedRunMode() == "Cut Plan Mode" && isfield(obj.Model.Trajectory, 'cutPlan') && ...
                    istable(obj.Model.Trajectory.cutPlan) && any(string(obj.Model.Trajectory.cutPlan.mode) == "cut")
                cutRows = obj.Model.Trajectory.cutPlan(string(obj.Model.Trajectory.cutPlan.mode) == "cut", :);
                target = struct('x', cutRows.leadX(1), 'y', cutRows.leadY(1), 'z', cutRows.leadZ(1));
                return;
            end

            target = trajectoryTargetAtIndex(obj.Model.Trajectory, 1);
        end

        function checkBoundsImpl(obj)
            obj.requireTrajectoryLoaded();

            analysis = obj.analyzeTrajectoryForExecution(obj.Model.Trajectory);
            summaryText = lw_build_bounds_summary_text(analysis);
            obj.Model.RunProgressText = "Bounds analysis";
            obj.Model.RunCurrentText = obj.formatRunStatusWithCurrentPosition(ternary(analysis.inBounds, 'Bounds ready', 'Bounds out of limits'));
            obj.Ports.logMessage(sprintf('Bounds check summary: %s', char(strrep(string(summaryText), newline, ' | '))));

            if ~obj.Ports.stageLaser.areStagesConnected()
                obj.Model.Services.dialog.alert(obj.Model.Figure, summaryText, 'Check Bounds');
                return;
            end

            choice = string(obj.Model.Services.dialog.confirm(obj.Model.Figure, ...
                sprintf('%s\n\nMove bounding box corners without laser?', summaryText), ...
                'Check Bounds', ...
                'Options', {'Move Corners', 'Close'}, ...
                'DefaultOption', 'Close', ...
                'CancelOption', 'Close', ...
                'Icon', 'question'));
            if choice ~= "Move Corners"
                return;
            end

            if ~analysis.inBounds
                error('Check Bounds move cancelled: the current plan extends outside the allowed travel range.');
            end

            obj.executeMotionTargetsNoLaser("Check Bounds", ...
                boundingBoxCornerTargets(analysis, obj.Model.Config.motion.yDisplayReference), "Bounds corner");
        end

        function preflight = buildPointRunPreflight(obj)
            obj.requireTrajectoryLoaded();
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            if obj.selectedRunMode() ~= "Point Mode"
                error('Select Point Mode to run point-by-point exposure.');
            end
            if ~supportsMode(obj.Model.Trajectory, "point")
                error('The current plan only supports %s.', char(obj.Model.Trajectory.modeSupport));
            end

            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            preflight.pauseSeconds = positiveScalar(obj.Model.Ui.PointPauseField.Value, 'Point pause');
            preflight.exposureTimeSeconds = positiveDurationMicroseconds(obj.Model.Ui.PointExposureField.Value, 'Point exposure');
            preflight.exposureMicroseconds = double(obj.Model.Ui.PointExposureField.Value);
            preflight.trajectory = obj.Model.Trajectory;
            preflight.analysis = obj.analyzeTrajectoryForExecution(preflight.trajectory);
            obj.validateTrajectoryForRun(preflight.trajectory);
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            preflight.summaryText = lw_build_run_preflight_summary_text( ...
                preflight, obj.selectedRunMode(), ...
                obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
        end

        function preflight = buildPulseRunPreflight(obj)
            obj.requireTrajectoryLoaded();
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            if obj.selectedRunMode() ~= "Stream Mode"
                error('Select Stream Mode to run a stream-capable plan during continuous motion.');
            end
            if ~supportsMode(obj.Model.Trajectory, "stream")
                error('The current plan does not support Stream Mode.');
            end
            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            preflight.pulseSpeedMmPerSecond = positiveScalar(obj.Model.Ui.StreamSpeedField.Value, 'Stream speed');
            preflight.powerPercent = trajectoryConstantPower(obj.Model.Trajectory);
            preflight.ttlGateWidthUs = obj.configuredTtlGateWidthUs();
            preflight.maxLaserRepetitionRateKHz = 1000 / preflight.ttlGateWidthUs;
            preflight.maxTriggerRateHz = obj.configuredMaxPulseTriggerRateHz();
            preflight.trajectory = obj.Model.Trajectory;
            preflight.analysis = obj.analyzeTrajectoryForExecution(preflight.trajectory);
            obj.validateTrajectoryForRun(preflight.trajectory);
            pulseAnalysis = analyzePulseTrajectory( ...
                preflight.trajectory, ...
                preflight.pulseSpeedMmPerSecond, ...
                preflight.ttlGateWidthUs, ...
                preflight.maxTriggerRateHz);
            preflight.pulseTimesSeconds = pulseAnalysis.pulseTimesSeconds;
            preflight.requiredTriggerRateHz = pulseAnalysis.requiredTriggerRateHz;
            preflight.minIntervalSeconds = pulseAnalysis.minIntervalSeconds;
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            preflight.summaryText = lw_build_pulse_run_preflight_summary_text( ...
                preflight, obj.selectedRunMode(), obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
        end

        function preflight = buildCutPlanRunPreflight(obj)
            obj.requireTrajectoryLoaded();
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            if obj.selectedRunMode() ~= "Cut Plan Mode"
                error('Select Cut Plan Mode to run writing-plan cut rows.');
            end
            if ~supportsMode(obj.Model.Trajectory, "cut")
                error('The current plan does not contain cut rows.');
            end
            if ~isfield(obj.Model.Trajectory, 'cutPlan') || ~istable(obj.Model.Trajectory.cutPlan)
                error('Cut Plan Mode requires a writing plan imported from CSV.');
            end

            planModes = string(obj.Model.Trajectory.cutPlan.mode);
            if any(planModes ~= "cut")
                error('Cut Plan Mode currently requires every writing-plan row to use mode=cut.');
            end

            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            preflight.trajectory = obj.Model.Trajectory;
            preflight.cutPlan = preflight.trajectory.cutPlan;
            preflight.cutGroups = lw_validate_cut_plan_rows_for_run(preflight.cutPlan);
            preflight.progressTotal = numel(preflight.cutGroups);
            preflight.analysis = obj.analyzeTrajectoryForExecution(preflight.trajectory);
            obj.validateTrajectoryForRun(preflight.trajectory);
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            preflight.summaryText = lw_build_cut_plan_preflight_summary_text( ...
                preflight, obj.selectedRunMode(), obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
        end

        function preflight = buildZSweepRunPreflight(obj)
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            if obj.selectedRunMode() ~= "Z Sweep Mode"
                error('Select Z Sweep Mode to run repeated direct Z sweeps.');
            end

            motion = obj.Ports.stageLaser.readAbsoluteMotion();
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
            sweep.preMoveMotion = motion;
            sweep.zAcceleration = motion.acceleration.z;
            sweep.pollIntervalSeconds = 0.05;

            if abs(sweep.zFront - sweep.zBack) <= 1e-9
                error('Z Sweep cancelled: Z Back and Z Front must be different.');
            end

            obj.Ports.validateTargetForUi(struct('x', sweep.x, 'y', sweep.y, 'z', sweep.zBack), 'Z Sweep');
            obj.Ports.validateTargetForUi(struct('x', sweep.x, 'y', sweep.y, 'z', sweep.zFront), 'Z Sweep');

            preflight = struct();
            preflight.sweep = sweep;
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            if obj.Model.Ui.ZSweepMatrixCheckBox.Value
                preflight.matrix = obj.buildZSweepMatrix(sweep);
                preflight.sweepJobs = preflight.matrix.runs;
                preflight.exposedSweepCount = preflight.matrix.exposedSweepCount;
                preflight.progressTotal = preflight.matrix.progressTotal;
                preflight.summaryText = lw_build_z_sweep_matrix_preflight_summary_text( ...
                    preflight, obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                    formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
            else
                preflight.sweepJobs = singleZSweepJob(sweep);
                preflight.exposedSweepCount = zSweepExposedSweepCount(sweep);
                preflight.progressTotal = zSweepProgressTotal(sweep);
                preflight.summaryText = lw_build_z_sweep_preflight_summary_text( ...
                    preflight, obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                    formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
            end
        end

        function matrix = buildZSweepMatrix(obj, baseSweep)
            xParameter = string(obj.Model.Ui.ZSweepMatrixXParamDropDown.Value);
            yParameter = string(obj.Model.Ui.ZSweepMatrixYParamDropDown.Value);
            xValues = zSweepMatrixParameterValues(xParameter, obj.Model.Ui.ZSweepMatrixXValuesField.Value);
            yValues = zSweepMatrixParameterValues(yParameter, obj.Model.Ui.ZSweepMatrixYValuesField.Value);
            pitchX = positiveScalar(obj.Model.Ui.ZSweepPitchXField.Value, 'Z Sweep matrix pitch X');
            pitchY = positiveScalar(obj.Model.Ui.ZSweepPitchYField.Value, 'Z Sweep matrix pitch Y');
            blockConfig = obj.zSweepMatrixBlockConfig();
            validateUniqueZSweepMatrixParameters([xParameter, yParameter, blockConfig.parameters]);

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
                        runSweep = applyZSweepBlockParameters(runSweep, blockConfig, blockColumn, blockRow);
                        runSweep = applyZSweepMatrixParameter(runSweep, xParameter, xValues(xIndex));
                        runSweep = applyZSweepMatrixParameter(runSweep, yParameter, yValues(yIndex));
                        runSweep.powerPercent = validatePowerPercent(runSweep.powerPercent, 'Z Sweep matrix power');
                        runSweep.x = baseSweep.x + (blockColumn - 1) * blockConfig.pitchX + (xIndex - 1) * pitchX;
                        runSweep.displayY = baseSweep.displayY + (blockRow - 1) * blockConfig.pitchY + (yIndex - 1) * pitchY;
                        runSweep.y = obj.Ports.displayYToStage(runSweep.displayY);

                        obj.Ports.validateTargetForUi(struct('x', runSweep.x, 'y', runSweep.y, 'z', runSweep.zBack), 'Z Sweep matrix');
                        obj.Ports.validateTargetForUi(struct('x', runSweep.x, 'y', runSweep.y, 'z', runSweep.zFront), 'Z Sweep matrix');

                        runs(runIndex) = struct( ...
                            'index', runIndex, ...
                            'xIndex', xIndex, ...
                            'yIndex', yIndex, ...
                            'blockIndex', blockIndex, ...
                            'blockColumn', blockColumn, ...
                            'blockRow', blockRow, ...
                            'xValueText', zSweepMatrixValueText(xParameter, xValues(xIndex)), ...
                            'yValueText', zSweepMatrixValueText(yParameter, yValues(yIndex)), ...
                            'blockText', zSweepBlockText(blockConfig, blockIndex), ...
                            'sweep', runSweep);
                        progressTotal = progressTotal + zSweepProgressTotal(runSweep);
                        exposedSweepCount = exposedSweepCount + zSweepExposedSweepCount(runSweep);
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
                xValues = zSweepMatrixParameterValues(xParameter, obj.Model.Ui.ZSweepBlockValues1Field.Value);
                selectedParameters(end + 1) = xParameter;
                selectedValues{end + 1} = xValues;
            end

            if yParameter ~= "None"
                yValues = zSweepMatrixParameterValues(yParameter, obj.Model.Ui.ZSweepBlockValues2Field.Value);
                selectedParameters(end + 1) = yParameter;
                selectedValues{end + 1} = yValues;
            end

            if isempty(selectedParameters)
                error('Z Sweep matrix blocks are enabled, but no block parameter is selected.');
            end

            if xParameter == "None"
                blockColumns = 1;
            else
                blockColumns = numel(xValues);
            end

            if yParameter == "None"
                blockRows = 1;
            else
                blockRows = numel(yValues);
            end
            blockCount = blockColumns * blockRows;

            blockConfig = struct( ...
                'enabled', true, ...
                'xParameter', xParameter, ...
                'yParameter', yParameter, ...
                'xValues', xValues, ...
                'yValues', yValues, ...
                'parameters', selectedParameters, ...
                'values', {selectedValues}, ...
                'count', blockCount, ...
                'columns', blockColumns, ...
                'rows', blockRows, ...
                'pitchX', positiveScalar(obj.Model.Ui.ZSweepBlockPitchXField.Value, 'Z Sweep block pitch X'), ...
                'pitchY', positiveScalar(obj.Model.Ui.ZSweepBlockPitchYField.Value, 'Z Sweep block pitch Y'));
        end

        function executeMotionTargetsNoLaser(obj, actionLabel, targets, statusPrefix)
            total = numel(targets);
            if total < 1
                return;
            end

            obj.Model.State.stopRequested = false;
            obj.Model.State.isBusy = true;
            if total == 1
                obj.Model.RunProgressText = char(actionLabel);
            else
                obj.Model.RunProgressText = sprintf('0 / %d', total);
            end
            obj.Model.RunCurrentText = "Preparing";
            obj.Ports.syncAll();

            try
                motion = obj.Ports.stageLaser.readAbsoluteMotion();
                obj.Ports.stageLaser.forceLaserSafeOff();

                for i = 1:total
                    target = targets(i);
                    obj.Ports.validateTargetForUi(target, char(actionLabel));

                    moveOptions = struct( ...
                        'shouldStopFcn', @() obj.Ports.stageLaser.isStopRequested(), ...
                        'yieldFcn', @() obj.Ports.stageLaser.yieldWithLivePosition(), ...
                        'pollIntervalSeconds', 0.02);
                    [obj.Model.State, wasStopped] = obj.Model.Services.stage.moveAbsolute( ...
                        obj.Model.State, target, motion, moveOptions);
                    obj.Ports.stageLaser.forceLaserSafeOff();
                    if wasStopped
                        break;
                    end

                    obj.Model.State.currentPosition = target;
                    if total == 1
                        obj.Model.RunProgressText = char(actionLabel);
                        statusText = char(statusPrefix);
                    else
                        obj.Model.RunProgressText = sprintf('%d / %d', i, total);
                        statusText = sprintf('%s %d/%d', char(statusPrefix), i, total);
                    end
                    obj.Model.RunCurrentText = obj.formatRunTargetStatus(target, statusText);
                    obj.Ports.syncPositionFields();
                    obj.syncRunStatus();
                    obj.Ports.trajectory.syncPreviewCurrentPosition();
                    obj.Model.Services.ui.drawnow('limitrate');

                    obj.Ports.logMessage(sprintf('%s reached at X %.3f, Y %.3f, Z %.3f mm.', ...
                        statusText, target.x, target.y, target.z));
                end

                if obj.Model.State.stopRequested
                    obj.Model.RunCurrentText = obj.formatRunStatusWithCurrentPosition("Stopped");
                    obj.Ports.logMessage(sprintf('%s stopped by user.', char(actionLabel)));
                else
                    obj.Ports.logMessage(sprintf('%s finished.', char(actionLabel)));
                end
            catch ME
                obj.finishRunCleanup();
                rethrow(ME);
            end

            obj.finishRunCleanup();
        end

        function updateRunProgress(obj, index, total, target, phase)
            if nargin < 5
                phase = "Done";
            end
            obj.Model.RunProgressText = obj.formatRunProgressText(index, total, phase);
            switch string(phase)
                case "Moving"
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Moving %d/%d', ...
                        target.x, target.y, target.z, index, total);
                case "Exposing"
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Exposing %d/%d', ...
                        target.x, target.y, target.z, index, total);
                    obj.Model.State.currentPosition = target;
                    obj.Ports.syncPositionFields();
                case "Stream"
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Stream %d/%d', ...
                        target.x, target.y, target.z, index, total);
                    obj.Model.State.currentPosition = target;
                    obj.Ports.syncPositionFields();
                case "Cut"
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Cut %d/%d complete', ...
                        target.x, obj.Ports.stageYToDisplay(target.y), target.z, index, total);
                    obj.Model.State.currentPosition = target;
                    obj.Ports.syncPositionFields();
                case {"Z Position", "Z Sweep", "Z Return"}
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | %s %d/%d', ...
                        target.x, obj.Ports.stageYToDisplay(target.y), target.z, char(phase), index, total);
                    obj.Model.State.currentPosition = target;
                    obj.Ports.syncPositionFields();
                otherwise
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Point %d/%d done', ...
                        target.x, target.y, target.z, index, total);
                    obj.Model.State.currentPosition = target;
                    obj.Ports.syncPositionFields();
            end
            obj.syncRunStatus();
            obj.Ports.trajectory.syncPreviewCurrentPosition();
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function textValue = formatRunProgressText(obj, index, total, phase)
            if total <= 0
                textValue = '0 / 0';
                return;
            end

            index = max(0, min(round(double(index)), total));
            completedUnits = obj.runCompletedUnits(index, total, phase);
            textValue = sprintf('%d / %d%s', index, total, ...
                char(lw_format_eta_suffix(obj.Model.RunEtaStartTic, obj.Model.RunEtaBaselineUnits, completedUnits, total)));
        end

        function completedUnits = runCompletedUnits(~, index, total, phase)
            index = max(0, min(round(double(index)), total));
            phase = string(phase);
            switch phase
                case "Moving"
                    phaseFraction = 0.15;
                case "Exposing"
                    phaseFraction = 0.75;
                case "Stream"
                    completedUnits = index;
                    return;
                case "Cut"
                    completedUnits = index;
                    return;
                case {"Z Position", "Z Sweep", "Z Return"}
                    phaseFraction = 0.15;
                case "Done"
                    completedUnits = index;
                    return;
                otherwise
                    phaseFraction = 0;
            end

            completedUnits = max(index - 1, 0) + phaseFraction;
            if index == 0
                completedUnits = 0;
            elseif phase == "Done"
                completedUnits = index;
            end
        end

        function syncRunStatus(obj)
            if obj.selectedRunMode() == "Z Sweep Mode"
                if obj.Model.Ui.ZSweepMatrixCheckBox.Value
                    obj.Model.Ui.RunSourceField.Value = 'Z Sweep Matrix';
                    obj.Model.Ui.RunSupportedField.Value = 'Power x speed grid';
                else
                    obj.Model.Ui.RunSourceField.Value = 'Z Sweep';
                    obj.Model.Ui.RunSupportedField.Value = 'Direct Z motion';
                end
            elseif isempty(obj.Model.Trajectory)
                obj.Model.Ui.RunSourceField.Value = 'None';
                obj.Model.Ui.RunSupportedField.Value = '-';
            else
                obj.Model.Ui.RunSourceField.Value = char(obj.Model.Trajectory.sourceType);
                obj.Model.Ui.RunSupportedField.Value = char(obj.Model.Trajectory.modeSupport);
            end
            obj.Model.Ui.RunProgressField.Value = char(obj.Model.RunProgressText);
            obj.Model.Ui.RunCurrentField.Value = char(obj.Model.RunCurrentText);
        end

        function syncRunParameterUi(obj)
            pointControls = { ...
                obj.Model.Ui.PointExposureLabel, obj.Model.Ui.PointExposureField, ...
                obj.Model.Ui.PointPauseLabel, obj.Model.Ui.PointPauseField};
            streamControls = { ...
                obj.Model.Ui.StreamSpeedLabel, obj.Model.Ui.StreamSpeedField, ...
                obj.Model.Ui.TTLGateWidthLabel, obj.Model.Ui.TTLGateWidthField};
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

            mode = obj.selectedRunMode();
            setVisibility(pointControls, mode == "Point Mode");
            setVisibility(streamControls, mode == "Stream Mode");
            setVisibility(zSweepControls, mode == "Z Sweep Mode");
            setVisibility(obj.Model.Ui.RunParameterHintLabel, true);

            switch mode
                case "Point Mode"
                    rowHeights = repmat({0}, 1, 17);
                    rowHeights([1, 16, 17]) = {'fit'};
                    obj.Model.Ui.RunParameterGrid.RowHeight = rowHeights;
                    obj.Model.Ui.RunParameterHintLabel.Text = 'Point Mode uses the execution power stored at each point in the loaded plan.';
                case "Stream Mode"
                    rowHeights = repmat({0}, 1, 17);
                    rowHeights([2, 3, 16, 17]) = {'fit'};
                    obj.Model.Ui.RunParameterGrid.RowHeight = rowHeights;
                    obj.Model.Ui.RunParameterHintLabel.Text = 'Stream Mode uses the loaded plan power and requires it to be constant.';
                case "Cut Plan Mode"
                    rowHeights = repmat({0}, 1, 17);
                    rowHeights([16, 17]) = {'fit'};
                    obj.Model.Ui.RunParameterGrid.RowHeight = rowHeights;
                    obj.Model.Ui.RunParameterHintLabel.Text = 'Cut Plan Mode uses plan power, cut speed, lead speed, and lead-in/out coordinates.';
                otherwise
                    rowHeights = repmat({0}, 1, 17);
                    rowHeights([2, 3, 4, 5, 6, 7, 8, 16, 17]) = {'fit'};
                    if obj.Model.Ui.ZSweepMatrixCheckBox.Value
                        rowHeights(9:12) = {'fit'};
                        if obj.Model.Ui.ZSweepBlockCheckBox.Value
                            rowHeights(13:15) = {'fit'};
                        end
                    end
                    obj.Model.Ui.RunParameterGrid.RowHeight = rowHeights;
                    if obj.Model.Ui.ZSweepMatrixCheckBox.Value
                        obj.Model.Ui.RunParameterHintLabel.Text = ['Matrix uses selected X/Y parameters; ', ...
                            'unselected parameters use the single Z Sweep values above. Open the Plan tab to preview.'];
                    else
                        obj.Model.Ui.RunParameterHintLabel.Text = 'Z Sweep Mode uses direct repeated Z moves. Open the Plan tab to preview.';
                    end
            end
        end

        function syncPauseResumeButton(obj, isStreamMode)
            if obj.Model.State.isPaused
                obj.Model.Ui.PauseResumeButton.Text = 'Resume';
                obj.Model.Ui.PauseResumeButton.Tooltip = 'Return to the paused point and continue the frozen run';
                setEnable(obj.Model.Ui.PauseResumeButton, ~obj.Model.State.isBusy && ~obj.Model.PausedManualMotionActive && ~isempty(obj.Model.State.resumeContext));
            elseif obj.Model.State.pauseRequested && obj.Model.State.isBusy
                obj.Model.Ui.PauseResumeButton.Text = 'Pause Requested';
                obj.Model.Ui.PauseResumeButton.Tooltip = 'The current step will finish before pausing';
                setEnable(obj.Model.Ui.PauseResumeButton, false);
            else
                obj.Model.Ui.PauseResumeButton.Text = 'Pause';
                obj.Model.Ui.PauseResumeButton.Tooltip = 'Pause at the next safe point or Z move boundary';
                setEnable(obj.Model.Ui.PauseResumeButton, obj.Model.State.isBusy && ~isStreamMode);
            end
        end

        function updateZSweepMatrixParameterEnableStates(obj, isZSweepMatrixEnabled)
            selectedParameters = strings(1, 0);
            if isZSweepMatrixEnabled
                selectedParameters = [ ...
                    string(obj.Model.Ui.ZSweepMatrixXParamDropDown.Value), ...
                    string(obj.Model.Ui.ZSweepMatrixYParamDropDown.Value)];
                if obj.Model.Ui.ZSweepBlockCheckBox.Value
                    selectedParameters = [selectedParameters, obj.zSweepSelectedBlockParameters()];
                end
            end

            obj.setSingleParameterEnableState('Power (%)', ...
                {obj.Model.Ui.ZSweepPowerLabel, obj.Model.Ui.ZSweepPowerField}, selectedParameters);
            obj.setSingleParameterEnableState('Sweep Speed (mm/s)', ...
                {obj.Model.Ui.ZSweepSpeedLabel, obj.Model.Ui.ZSweepSpeedField}, selectedParameters);
            obj.setSingleParameterEnableState('Return Speed (mm/s)', ...
                {obj.Model.Ui.ZSweepReturnSpeedLabel, obj.Model.Ui.ZSweepReturnSpeedField}, selectedParameters);
            obj.setSingleParameterEnableState('Repeat Count', ...
                {obj.Model.Ui.ZSweepRepeatLabel, obj.Model.Ui.ZSweepRepeatField}, selectedParameters);
            obj.setSingleParameterEnableState('Exposure Direction', ...
                {obj.Model.Ui.ZSweepDirectionLabel, obj.Model.Ui.ZSweepDirectionDropDown}, selectedParameters);
        end

        function setSingleParameterEnableState(obj, parameterName, controls, selectedParameters)
            isSelectedForMatrix = any(selectedParameters == string(parameterName));
            setEnable(controls, ~obj.Model.State.isBusy && ~obj.Model.State.isPaused && ~isSelectedForMatrix);
        end

        function selectedParameters = zSweepSelectedBlockParameters(obj)
            selectedParameters = strings(1, 0);
            blockParameters = [ ...
                string(obj.Model.Ui.ZSweepBlockParam1DropDown.Value), ...
                string(obj.Model.Ui.ZSweepBlockParam2DropDown.Value)];
            for blockParameterIndex = 1:numel(blockParameters)
                if blockParameters(blockParameterIndex) ~= "None"
                    selectedParameters(end + 1) = blockParameters(blockParameterIndex); %#ok<AGROW>
                end
            end
        end

        function requireTrajectoryLoaded(obj)
            if isempty(obj.Model.Trajectory)
                error('No plan is loaded.');
            end
            if obj.Model.TrajectoryInputsDirty
                error('Plan power input changed. Regenerate or re-import the plan before running.');
            end
        end

        function mode = selectedRunMode(obj)
            mode = string(obj.Model.Ui.RunModeGroup.SelectedObject.Text);
        end

        function value = configuredTtlGateWidthUs(obj)
            value = positiveScalar(obj.Model.Ui.TTLGateWidthField.Value, 'TTL Gate Width');
        end

        function value = configuredMaxPulseTriggerRateHz(obj)
            if ~isfield(obj.Model.Config, 'stage') || ~isfield(obj.Model.Config.stage, 'maxPulseTriggerRateHz')
                error('Max Trigger Rate is not configured. Set config.stage.maxPulseTriggerRateHz in lw_hardware_config.m.');
            end
            value = positiveScalar(obj.Model.Config.stage.maxPulseTriggerRateHz, 'Max Trigger Rate');
        end

        function validateTrajectoryForRun(obj, traj)
            if ~isfield(traj, 'power') || numel(traj.power) ~= numel(traj.x)
                error('The loaded plan must contain one execution power value per point.');
            end
            validatePowerPercentValues(traj.power, 'Plan execution power');
            if isfield(traj, 'cutPlan') && istable(traj.cutPlan) && ...
                    ismember('power', traj.cutPlan.Properties.VariableNames)
                validatePowerPercentValues(traj.cutPlan.power, 'Cut plan execution power');
            end
            analysis = obj.analyzeTrajectoryForExecution(traj);
            if ~analysis.inBounds
                error('%s', char(analysis.firstViolation.message));
            end
        end

        function analysis = analyzeTrajectoryForExecution(obj, traj)
            analysis = lw_analyze_trajectory_for_execution(traj, ...
                obj.Model.Config.motion.travelLimits, obj.Model.Config.motion.yDisplayReference);
        end

        function textValue = formatRunTargetStatus(~, target, statusText)
            textValue = sprintf('X %s | Y %s | Z %s | %s', ...
                formatValue(target.x), formatValue(target.y), formatValue(target.z), char(statusText));
        end

        function textValue = formatRunStatusWithCurrentPosition(obj, statusText)
            textValue = obj.formatRunTargetStatus(obj.Model.State.currentPosition, statusText);
        end

    end
end
