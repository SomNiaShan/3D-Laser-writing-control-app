function [state, result] = lw_run_point_mode(state, config, trajectory, options)
%LW_RUN_POINT_MODE Execute a point-by-point write workflow.

if nargin < 4 || isempty(options)
    options = struct();
end
if ~isfield(options, 'pauseSeconds')
    options.pauseSeconds = config.execution.pointPause;
end
if ~isfield(options, 'exposureTimeSeconds')
    options.exposureTimeSeconds = config.execution.pointExposureTime;
end
if ~isfield(options, 'moveFcn') || isempty(options.moveFcn)
    options.moveFcn = @lw_move_absolute;
end
if ~isfield(options, 'exposureFcn') || isempty(options.exposureFcn)
    options.exposureFcn = @lw_manual_exposure;
end
if ~isfield(options, 'motion')
    options.motion = struct( ...
        'velocity', config.motion.defaultVelocity, ...
        'acceleration', config.motion.defaultAcceleration);
end
if ~isfield(options, 'shouldStopFcn')
    options.shouldStopFcn = @() false;
end
if ~isfield(options, 'progressFcn')
    options.progressFcn = [];
end
if ~isfield(options, 'yieldFcn')
    options.yieldFcn = @() drawnow;
end
if ~isfield(options, 'laserStateFcn')
    options.laserStateFcn = [];
end
if ~isfield(options, 'pauseRequestedFcn') || isempty(options.pauseRequestedFcn)
    options.pauseRequestedFcn = @() false;
end
if ~isfield(options, 'startIndex') || isempty(options.startIndex)
    options.startIndex = 1;
end

[trajectory, ~] = lw_prepare_point_run_trajectory( ...
    trajectory, options.exposureTimeSeconds, options.pauseSeconds, config);
pointCount = numel(trajectory.x);
startIndex = max(1, min(round(double(options.startIndex)), pointCount + 1));
result = localRunResult("finished", pointCount + 1, localEmptyTarget(), pointCount);

if startIndex > pointCount
    return;
end

for i = startIndex:pointCount
    options.yieldFcn();
    if options.shouldStopFcn()
        result = localRunResult("stopped", i, localCurrentPositionTarget(state), i - 1);
        break;
    end

    target = struct( ...
        'x', trajectory.x(i), ...
        'y', trajectory.y(i), ...
        'z', trajectory.z(i));

    invokeProgressFcn(options.progressFcn, i, pointCount, target, "Moving");

    moveOptions = struct( ...
        'shouldStopFcn', options.shouldStopFcn, ...
        'yieldFcn', options.yieldFcn, ...
        'pollIntervalSeconds', 0.1);
    [state, wasStopped] = options.moveFcn(state, target, options.motion, moveOptions);
    if wasStopped
        result = localRunResult("stopped", i, localCurrentPositionTarget(state), i - 1);
        break;
    end

    options.yieldFcn();
    if options.shouldStopFcn()
        result = localRunResult("stopped", i, target, i - 1);
        break;
    end
    if options.pauseRequestedFcn()
        result = localRunResult("paused", i, target, i - 1);
        break;
    end

    settleSeconds = trajectory.preWritePauseSeconds(i);
    if settleSeconds > 0
        invokeProgressFcn(options.progressFcn, i, pointCount, target, "Settling");
        [wasStopped, wasPaused] = localPauseWithCallbacks(settleSeconds, options);
        if wasStopped
            result = localRunResult("stopped", i, target, i - 1);
            break;
        end
        if wasPaused
            result = localRunResult("paused", i, target, i - 1);
            break;
        end
    end

    invokeProgressFcn(options.progressFcn, i, pointCount, target, "Exposing");
    wasStopped = options.exposureFcn(state, config, trajectory.power(i), ...
        trajectory.dwellSeconds(i), options.laserStateFcn, ...
        options.shouldStopFcn, options.yieldFcn);
    if wasStopped
        result = localRunResult("stopped", i, target, i - 1);
        break;
    end

    invokeProgressFcn(options.progressFcn, i, pointCount, target, "Done");

    options.yieldFcn();
    if options.shouldStopFcn()
        result = localRunResult("stopped", i + 1, target, i);
        break;
    end
    if i < pointCount && options.pauseRequestedFcn()
        result = localRunResult("paused", i + 1, target, i);
        break;
    end

end
end

function invokeProgressFcn(progressFcn, index, total, target, phase)
if isempty(progressFcn)
    return;
end

try
    progressFcn(index, total, target, phase);
catch
    progressFcn(index, total, target);
end
end

function [wasStopped, wasPaused] = localPauseWithCallbacks(seconds, options)
wasStopped = false;
wasPaused = false;
if seconds <= 0
    return;
end

timerStart = tic;
while toc(timerStart) < seconds
    options.yieldFcn();
    if options.shouldStopFcn()
        wasStopped = true;
        return;
    end
    if options.pauseRequestedFcn()
        wasPaused = true;
        return;
    end
    remainingSeconds = seconds - toc(timerStart);
    pause(max(min(remainingSeconds, 0.02), 0));
end
end

function result = localRunResult(status, nextPointIndex, returnTarget, lastCompletedIndex)
result = struct( ...
    'status', string(status), ...
    'nextPointIndex', nextPointIndex, ...
    'returnTarget', returnTarget, ...
    'lastCompletedIndex', lastCompletedIndex);
end

function target = localEmptyTarget()
target = struct('x', NaN, 'y', NaN, 'z', NaN);
end

function target = localCurrentPositionTarget(state)
if isfield(state, 'currentPosition') && isstruct(state.currentPosition)
    target = state.currentPosition;
else
    target = localEmptyTarget();
end
end
