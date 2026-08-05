classdef RunController < handle
    %RUNCONTROLLER Execute prepared plans with preflight, pause, and recovery.

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
            obj.requirePreparedPlan();
            runMode = obj.selectedRunMode();
            switch runMode
                case "Point Mode"
                    preflight = obj.buildPointRunPreflight();
                case "Z Sweep Mode"
                    preflight = obj.buildZSweepRunPreflight();
                case "Path Plan Mode"
                    preflight = obj.buildPathPlanRunPreflight();
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
                    options.motion = preflight.motion;
                    options.moveFcn = obj.Model.Services.stage.moveAbsolute;
                    options.exposureFcn = obj.Model.Services.laser.manualExposure;
                    options.laserStateFcn = @(isOn) obj.Ports.stageLaser.setLaserState(isOn);
                    [obj.Model.State, pointResult] = obj.Model.Services.execution.runPoint( ...
                        obj.Model.State, obj.Model.Config, preflight.trajectory, options);
                    runResult = obj.runResultFromPoint(preflight, pointResult);

                case "Z Sweep Mode"
                    options.laserStateFcn = @(isOn) obj.Ports.stageLaser.setLaserState(isOn);
                    runResult = obj.runZSweepJobs(preflight, options, resumeContext);

                case "Path Plan Mode"
                    if isempty(resumeContext)
                        options.startPathGroupIndex = 1;
                        obj.Ports.logMessage(sprintf( ...
                            'Path Plan Mode started with %d path group(s).', ...
                            preflight.progressTotal));
                    else
                        options.startPathGroupIndex = resumeContext.nextPathGroupIndex;
                        obj.Ports.logMessage(sprintf( ...
                            'Path Plan Mode resumed at path group %d of %d.', ...
                            options.startPathGroupIndex, preflight.progressTotal));
                    end
                    options.motion = preflight.motion;
                    options.laserStateFcn = @(isOn) obj.Ports.stageLaser.setLaserState(isOn);
                    [obj.Model.State, pathResult] = obj.Model.Services.execution.runPathPlan( ...
                        obj.Model.State, obj.Model.Config, preflight.trajectory, options);
                    runResult = obj.runResultFromPathPlan(preflight, pathResult);

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

        function runResult = runResultFromPathPlan(obj, preflight, pathResult)
            if pathResult.status == "paused"
                resumeContext = struct( ...
                    'kind', "pathPlan", ...
                    'runMode', "Path Plan Mode", ...
                    'preflight', preflight, ...
                    'nextPathGroupIndex', pathResult.nextPathGroupIndex, ...
                    'returnTarget', pathResult.returnTarget);
                runResult = obj.makeRunResult( ...
                    "paused", pathResult.returnTarget, resumeContext);
                return;
            end
            runResult = obj.makeRunResult( ...
                pathResult.status, pathResult.returnTarget, []);
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
                case "pathPlan"
                    if isfield(resumeContext, 'nextPathGroupIndex')
                        completedUnits = max( ...
                            0, double(resumeContext.nextPathGroupIndex) - 1);
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
                case "pathPlan"
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
            obj.requireTrajectoryPlan();
            obj.Ports.stageLaser.requireStagesConnected();

            target = obj.firstRunTargetForCurrentMode();
            obj.Ports.validateTargetForUi(target, 'Go to First Point');
            obj.executeMotionTargetsNoLaser("Go to First Point", target, "Go to First Point");
        end

        function target = firstRunTargetForCurrentMode(obj)
            trajectory = obj.Model.PreparedPlan.trajectory;
            if obj.selectedRunMode() == "Path Plan Mode" && ...
                    isfield(trajectory, 'writingPlan') && ...
                    istable(trajectory.writingPlan) && ...
                    any(string(trajectory.writingPlan.operation) == "path")
                pathRows = trajectory.writingPlan( ...
                    string(trajectory.writingPlan.operation) == "path", :);
                target = struct( ...
                    'x', pathRows.x(1), 'y', pathRows.y(1), 'z', pathRows.z(1));
                return;
            end

            target = trajectoryTargetAtIndex(trajectory, 1);
        end

        function checkBoundsImpl(obj)
            obj.requireTrajectoryPlan();

            analysis = obj.analyzeTrajectoryForExecution( ...
                obj.Model.PreparedPlan.trajectory);
            summaryText = lw_build_bounds_summary_text(analysis);
            obj.Model.RunProgressText = "Bounds analysis";
            obj.Model.RunCurrentText = obj.formatRunStatusWithCurrentPosition(ternary(analysis.inBounds, 'Bounds ready', 'Bounds out of limits'));
            obj.Ports.logMessage(sprintf('Bounds check summary: %s', char(strrep(string(summaryText), newline, ' | '))));

            if ~obj.Ports.stageLaser.areStagesConnected()
                obj.Model.Services.dialog.alert(obj.Model.Figure, summaryText, 'Check Bounds');
                return;
            end

            if ~analysis.inBounds
                obj.Model.Services.dialog.alert(obj.Model.Figure, summaryText, 'Check Bounds');
                return;
            end

            speedMmPerSecond = obj.promptBoundsCheckSpeed();
            if isempty(speedMmPerSecond)
                obj.Ports.logMessage('Check Bounds corner move cancelled before motion.');
                return;
            end

            choice = string(obj.Model.Services.dialog.confirm(obj.Model.Figure, ...
                sprintf(['%s\n\nMove bounding box corners without laser ', ...
                    'at %.3g mm/s?'], summaryText, speedMmPerSecond), ...
                'Check Bounds', ...
                'Options', {'Move Corners', 'Close'}, ...
                'DefaultOption', 'Close', ...
                'CancelOption', 'Close', ...
                'Icon', 'question'));
            if choice ~= "Move Corners"
                return;
            end

            obj.executeMotionTargetsNoLaser("Check Bounds", ...
                boundingBoxCornerTargets(analysis, obj.Model.Config.motion.yDisplayReference), ...
                "Bounds corner", speedMmPerSecond);
        end

        function speedMmPerSecond = promptBoundsCheckSpeed(obj)
            defaultSpeed = obj.Model.Config.motion.defaultManualVelocity;
            defaultSpeed = min([defaultSpeed.x, defaultSpeed.y, defaultSpeed.z]);
            defaultText = sprintf('%.3g', defaultSpeed);
            answer = obj.Model.Services.dialog.prompt( ...
                {'Move speed (mm/s):'}, ...
                'Check Bounds Move Speed', ...
                [1, 35], ...
                {defaultText});
            if isempty(answer)
                speedMmPerSecond = [];
                return;
            end

            if iscell(answer)
                answer = answer{1};
            end
            speedMmPerSecond = positiveScalar( ...
                str2double(string(answer)), 'Check Bounds move speed');
        end

        function preflight = buildPointRunPreflight(obj)
            obj.requirePreparedPlan("point");
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            plan = obj.Model.PreparedPlan;
            if ~supportsMode(plan.trajectory, "point")
                error('The current plan only supports %s.', ...
                    char(plan.trajectory.modeSupport));
            end

            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            [preflight.trajectory, preflight.pointTiming] = ...
                lw_prepare_point_run_trajectory(plan.trajectory, ...
                plan.defaultDwellSeconds, plan.defaultSettleSeconds, ...
                obj.Model.Config);
            preflight.analysis = obj.analyzeTrajectoryForExecution(preflight.trajectory);
            obj.validateTrajectoryForRun(preflight.trajectory);
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            preflight.summaryText = lw_build_run_preflight_summary_text( ...
                preflight, obj.selectedRunMode(), ...
                obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
        end

        function preflight = buildPathPlanRunPreflight(obj)
            obj.requirePreparedPlan("path");
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            plan = obj.Model.PreparedPlan;
            if ~supportsMode(plan.trajectory, "path")
                error('The current plan does not contain path segments.');
            end
            if ~isfield(plan.trajectory, 'writingPlan') || ...
                    ~istable(plan.trajectory.writingPlan)
                error('Path Plan Mode requires a writing plan imported from CSV.');
            end

            operations = string(plan.trajectory.writingPlan.operation);
            if any(operations ~= "path")
                error(['Path Plan Mode requires every writing-plan row ', ...
                    'to use operation=path.']);
            end

            preflight = struct();
            preflight.motion = obj.Ports.stageLaser.readAbsoluteMotion();
            preflight.trajectory = plan.trajectory;
            preflight.writingPlan = preflight.trajectory.writingPlan;
            preflight.pathGroups = lw_validate_path_plan_for_run(preflight.writingPlan);
            preflight.progressTotal = numel(preflight.pathGroups);
            preflight.analysis = obj.analyzeTrajectoryForExecution(preflight.trajectory);
            obj.validateTrajectoryForRun(preflight.trajectory);
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            preflight.summaryText = lw_build_path_plan_preflight_summary_text( ...
                preflight, obj.selectedRunMode(), obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
        end

        function preflight = buildZSweepRunPreflight(obj)
            obj.requirePreparedPlan("z_sweep");
            obj.Ports.stageLaser.requireStagesConnected();
            obj.Ports.stageLaser.requireDAQConnected();

            motion = obj.Ports.stageLaser.readAbsoluteMotion();
            plan = obj.Model.PreparedPlan;
            sweep = obj.sweepWithRunMotion(plan.sweep, motion);

            preflight = struct();
            preflight.sweep = sweep;
            preflight.carbideSnapshot = obj.Ports.carbide.currentCarbideSnapshot();
            preflight.sweepJobs = plan.sweepJobs;
            for jobIndex = 1:numel(preflight.sweepJobs)
                preflight.sweepJobs(jobIndex).sweep = obj.sweepWithRunMotion( ...
                    preflight.sweepJobs(jobIndex).sweep, motion);
            end
            preflight.exposedSweepCount = plan.exposedSweepCount;
            preflight.progressTotal = plan.progressTotal;
            if plan.isMatrix
                preflight.matrix = plan.matrix;
                preflight.matrix.runs = preflight.sweepJobs;
                preflight.summaryText = lw_build_z_sweep_matrix_preflight_summary_text( ...
                    preflight, obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                    formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
            else
                preflight.summaryText = lw_build_z_sweep_preflight_summary_text( ...
                    preflight, obj.Ports.stageLaser.areStagesConnected(), obj.Ports.stageLaser.areDAQConnected(), ...
                    formatCarbideSnapshot(preflight.carbideSnapshot), obj.Ports.carbide.autoStandbyAfterRunSummaryText());
            end
        end

        function sweep = sweepWithRunMotion(~, sweep, motion)
            sweep.preMoveMotion = motion;
            sweep.zAcceleration = motion.acceleration.z;
            sweep.pollIntervalSeconds = 0.05;
        end

        function executeMotionTargetsNoLaser(obj, actionLabel, targets, statusPrefix, speedMmPerSecond)
            if nargin < 5
                speedMmPerSecond = [];
            end
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
                if ~isempty(speedMmPerSecond)
                    speedMmPerSecond = positiveScalar( ...
                        speedMmPerSecond, sprintf('%s move speed', char(actionLabel)));
                    motion.velocity = struct( ...
                        'x', speedMmPerSecond, ...
                        'y', speedMmPerSecond, ...
                        'z', speedMmPerSecond);
                end
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
                case "Settling"
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Settling %d/%d', ...
                        target.x, target.y, target.z, index, total);
                    obj.Model.State.currentPosition = target;
                    obj.Ports.syncPositionFields();
                case "Exposing"
                    obj.Model.RunCurrentText = sprintf('X %.3f | Y %.3f | Z %.3f | Exposing %d/%d', ...
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
                case "Settling"
                    phaseFraction = 0.5;
                case "Exposing"
                    phaseFraction = 0.75;
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
            if isempty(obj.Model.PreparedPlan)
                obj.Model.Ui.RunPlanTypeField.Value = 'None';
                obj.Model.Ui.RunSourceField.Value = 'None';
                obj.Model.Ui.RunSupportedField.Value = 'Prepare a plan on the Plan tab';
            else
                plan = obj.Model.PreparedPlan;
                obj.Model.Ui.RunPlanTypeField.Value = char(obj.planTypeText(plan));
                obj.Model.Ui.RunSourceField.Value = char(string(plan.sourceType));
                if obj.Model.TrajectoryInputsDirty
                    obj.Model.Ui.RunSupportedField.Value = ...
                        'Inputs changed - prepare again';
                else
                    obj.Model.Ui.RunSupportedField.Value = ...
                        'Ready - execution derived from plan';
                end
            end
            obj.Model.Ui.RunProgressField.Value = char(obj.Model.RunProgressText);
            obj.Model.Ui.RunCurrentField.Value = char(obj.Model.RunCurrentText);
        end

        function syncPauseResumeButton(obj)
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
                setEnable(obj.Model.Ui.PauseResumeButton, obj.Model.State.isBusy);
            end
        end

        function requirePreparedPlan(obj, expectedKind)
            if isempty(obj.Model.PreparedPlan)
                error('No plan is prepared. Prepare one on the Plan tab first.');
            end
            if obj.Model.TrajectoryInputsDirty
                error('Plan inputs changed. Prepare the plan again before running.');
            end
            if nargin >= 2 && string(obj.Model.PreparedPlan.kind) ~= string(expectedKind)
                error('Prepared plan type changed unexpectedly. Prepare the plan again.');
            end
        end

        function requireTrajectoryPlan(obj)
            obj.requirePreparedPlan();
            if ~isfield(obj.Model.PreparedPlan, 'trajectory')
                error(['The prepared Z Sweep has no point list. ', ...
                    'Use the Plan preview to inspect its bounds.']);
            end
        end

        function mode = selectedRunMode(obj)
            if isempty(obj.Model.PreparedPlan)
                mode = "No Plan";
                return;
            end
            switch string(obj.Model.PreparedPlan.kind)
                case "point"
                    mode = "Point Mode";
                case "path"
                    mode = "Path Plan Mode";
                case "z_sweep"
                    mode = "Z Sweep Mode";
                otherwise
                    mode = "Unsupported Plan";
            end
        end

        function textValue = planTypeText(~, plan)
            switch string(plan.kind)
                case "point"
                    textValue = "Point";
                case "path"
                    textValue = "Path";
                case "z_sweep"
                    if plan.isMatrix
                        textValue = "Z Sweep Matrix";
                    else
                        textValue = "Z Sweep";
                    end
                otherwise
                    textValue = "Unsupported";
            end
        end

        function validateTrajectoryForRun(obj, traj)
            if ~isfield(traj, 'power') || numel(traj.power) ~= numel(traj.x)
                error('The loaded plan must contain one execution power value per point.');
            end
            validatePowerPercentValues(traj.power, 'Plan execution power');
            if isfield(traj, 'writingPlan') && istable(traj.writingPlan) && ...
                    ismember('power', traj.writingPlan.Properties.VariableNames)
                validatePowerPercentValues( ...
                    traj.writingPlan.power, 'Writing plan execution power');
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
