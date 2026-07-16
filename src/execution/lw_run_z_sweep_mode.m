function [state, result] = lw_run_z_sweep_mode(state, config, sweep, options)
%LW_RUN_Z_SWEEP_MODE Execute repeated direct Z sweeps without Zaber streams.

if nargin < 4 || isempty(options)
    options = struct();
end
if ~isfield(options, 'shouldStopFcn') || isempty(options.shouldStopFcn)
    options.shouldStopFcn = @() false;
end
if ~isfield(options, 'progressFcn')
    options.progressFcn = [];
end
if ~isfield(options, 'yieldFcn') || isempty(options.yieldFcn)
    options.yieldFcn = @() drawnow;
end
if ~isfield(options, 'laserStateFcn')
    options.laserStateFcn = [];
end
if ~isfield(options, 'pauseRequestedFcn') || isempty(options.pauseRequestedFcn)
    options.pauseRequestedFcn = @() false;
end
if ~isfield(options, 'startStepIndex') || isempty(options.startStepIndex)
    options.startStepIndex = 1;
end

import zaber.motion.Units;

steps = localBuildSteps(sweep);
progressTotal = numel(steps);
startStepIndex = max(1, min(round(double(options.startStepIndex)), progressTotal + 1));
result = localSweepResult("finished", progressTotal + 1, localStepReturnTarget(steps(end)), progressTotal);
laserOutputIsActive = [];
busyPollOptions = struct( ...
    'maxRetries', 3, ...
    'retryDelaySeconds', max(0.05, sweep.pollIntervalSeconds));

if startStepIndex > progressTotal
    return;
end

try
    localSafeOutputsOff(true);

    for stepIndex = startStepIndex:progressTotal
        if options.shouldStopFcn()
            state.stopRequested = true;
            result = localSweepResult("stopped", stepIndex, localCurrentPositionTarget(state), stepIndex - 1);
            return;
        end

        try
            step = steps(stepIndex);
            if step.isInitial
                localUpdateProgress(stepIndex, step.target, step.phase);
                moveOptions = struct( ...
                    'shouldStopFcn', options.shouldStopFcn, ...
                    'yieldFcn', options.yieldFcn, ...
                    'pollIntervalSeconds', sweep.pollIntervalSeconds);
                [state, wasStopped] = lw_move_absolute(state, step.target, sweep.preMoveMotion, moveOptions);
            else
                if step.isExposed
                    localLaserOn();
                    speed = sweep.sweepSpeedMmPerSecond;
                else
                    localSafeOutputsOff();
                    speed = sweep.returnSpeedMmPerSecond;
                end
                wasStopped = localMoveZAbsolute(step.target.z, speed, sweep.zAcceleration, ...
                    stepIndex, step.target, step.phase);
            end

            localSafeOutputsOff();
            if wasStopped || options.shouldStopFcn()
                state.stopRequested = true;
                result = localSweepResult("stopped", stepIndex, localCurrentPositionTarget(state), stepIndex - 1);
                return;
            end

            if stepIndex < progressTotal && options.pauseRequestedFcn()
                result = localSweepResult("paused", stepIndex + 1, step.target, stepIndex);
                return;
            end
        catch ME
            localSafeOutputsOff(true);
            if lw_is_recoverable_zaber_error(ME)
                result = localSweepResult( ...
                    "hardware_error", stepIndex, localStepStartTarget(steps, stepIndex), stepIndex - 1);
                result.errorMessage = string(ME.message);
                return;
            end
            rethrow(ME);
        end
    end

    localSafeOutputsOff(true);
catch ME
    localSafeOutputsOff(true);
    rethrow(ME);
end

    function wasStopped = localMoveZAbsolute(targetZ, speedMmPerSecond, accelerationMmPerSecondSquared, progressStep, progressTarget, phase)
        wasStopped = false;
        state.axes.z.moveAbsolute( ...
            targetZ, Units.LENGTH_MILLIMETRES, false, ...
            speedMmPerSecond, Units.VELOCITY_MILLIMETRES_PER_SECOND, ...
            accelerationMmPerSecondSquared, Units.ACCELERATION_MILLIMETRES_PER_SECOND_SQUARED);

        localUpdateProgress(progressStep, progressTarget, phase);

        while lw_axis_is_busy(state.axes.z, busyPollOptions)
            options.yieldFcn();
            if options.shouldStopFcn()
                try
                    state.axes.z.stop(false);
                catch
                end
                state.stopRequested = true;
                wasStopped = true;
                try
                    state.currentPosition = lw_get_position(state);
                catch
                end
                return;
            end
            pause(sweep.pollIntervalSeconds);
        end

        state.currentPosition = struct('x', sweep.x, 'y', sweep.y, 'z', targetZ);
    end

    function localLaserOn()
        if isequal(laserOutputIsActive, true)
            return;
        end

        lw_set_laser_power(state, sweep.powerPercent);
        lw_set_stage_pulse_trigger(state, true, config);
        laserOutputIsActive = true;
        localNotifyLaserState(true);
    end

    function localSafeOutputsOff(forceWrite)
        if nargin < 1
            forceWrite = false;
        end
        if ~forceWrite && isequal(laserOutputIsActive, false)
            return;
        end

        try
            lw_set_stage_pulse_trigger(state, false, config);
        catch
        end
        try
            lw_set_laser_power(state, 0);
        catch
        end
        laserOutputIsActive = false;
        localNotifyLaserState(false);
    end

    function localNotifyLaserState(isOn)
        if isempty(options.laserStateFcn)
            return;
        end
        options.laserStateFcn(logical(isOn));
    end

    function localUpdateProgress(index, target, phase)
        if isempty(options.progressFcn)
            return;
        end
        options.progressFcn(index, progressTotal, target, phase);
    end
end

function steps = localBuildSteps(sweep)
stepCount = localProgressTotal(sweep);
steps = repmat(localStep(sweep, localInitialZ(sweep), false, "Z Position", true), stepCount, 1);
writeIndex = 0;

appendStep(localInitialZ(sweep), false, "Z Position", true);
switch string(sweep.exposureDirection)
    case "Back -> Front"
        for repeatIndex = 1:sweep.repeatCount
            appendStep(sweep.zFront, true, "Z Sweep", false);
            appendStep(sweep.zBack, false, "Z Return", false);
        end

    case "Front -> Back"
        for repeatIndex = 1:sweep.repeatCount
            appendStep(sweep.zBack, true, "Z Sweep", false);
            if repeatIndex < sweep.repeatCount
                appendStep(sweep.zFront, false, "Z Return", false);
            end
        end

    case "Both Directions"
        for repeatIndex = 1:sweep.repeatCount
            appendStep(sweep.zFront, true, "Z Sweep", false);
            appendStep(sweep.zBack, true, "Z Sweep", false);
        end

    otherwise
        error('Unsupported Z Sweep exposure direction: %s', char(sweep.exposureDirection));
end

steps = steps(1:writeIndex);

    function appendStep(targetZ, isExposed, phase, isInitial)
        writeIndex = writeIndex + 1;
        steps(writeIndex) = localStep(sweep, targetZ, isExposed, phase, isInitial);
    end
end

function step = localStep(sweep, targetZ, isExposed, phase, isInitial)
step = struct( ...
    'target', struct('x', sweep.x, 'y', sweep.y, 'z', targetZ), ...
    'isExposed', logical(isExposed), ...
    'phase', string(phase), ...
    'isInitial', logical(isInitial));
end

function result = localSweepResult(status, nextStepIndex, returnTarget, lastCompletedStepIndex)
result = struct( ...
    'status', string(status), ...
    'nextStepIndex', nextStepIndex, ...
    'returnTarget', returnTarget, ...
    'lastCompletedStepIndex', lastCompletedStepIndex, ...
    'errorMessage', "");
end

function target = localStepReturnTarget(step)
target = step.target;
end

function target = localStepStartTarget(steps, stepIndex)
if stepIndex <= 1
    target = steps(1).target;
else
    target = steps(stepIndex - 1).target;
end
end

function target = localCurrentPositionTarget(state)
if isfield(state, 'currentPosition') && isstruct(state.currentPosition)
    target = state.currentPosition;
else
    target = struct('x', NaN, 'y', NaN, 'z', NaN);
end
end

function count = localProgressTotal(sweep)
switch string(sweep.exposureDirection)
    case "Front -> Back"
        count = 1 + sweep.repeatCount + max(sweep.repeatCount - 1, 0);
    otherwise
        count = 1 + 2 * sweep.repeatCount;
end
end

function initialZ = localInitialZ(sweep)
if string(sweep.exposureDirection) == "Front -> Back"
    initialZ = sweep.zFront;
else
    initialZ = sweep.zBack;
end
end
