function [state, result] = lw_run_cut_plan_mode(state, config, trajectory, options)
%LW_RUN_CUT_PLAN_MODE Execute cut rows with laser-off lead-in/out stream moves.

if nargin < 4 || isempty(options)
    options = struct();
end
if ~isfield(options, 'motion') || isempty(options.motion)
    options.motion = struct( ...
        'velocity', config.motion.defaultVelocity, ...
        'acceleration', config.motion.defaultAcceleration);
end
if ~isfield(options, 'shouldStopFcn') || isempty(options.shouldStopFcn)
    options.shouldStopFcn = @() false;
end
if ~isfield(options, 'pauseRequestedFcn') || isempty(options.pauseRequestedFcn)
    options.pauseRequestedFcn = @() false;
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
if ~isfield(options, 'startCutIndex') || isempty(options.startCutIndex)
    options.startCutIndex = 1;
end

if ~isfield(trajectory, 'cutPlan') || ~istable(trajectory.cutPlan)
    error('Cut Plan Mode requires a loaded writing plan with cut rows.');
end

cutPlan = trajectory.cutPlan(string(trajectory.cutPlan.mode) == "cut", :);
cutCount = height(cutPlan);
if cutCount == 0
    error('Cut Plan Mode requires at least one cut row.');
end

cutGroups = lw_validate_cut_plan_rows_for_run(cutPlan);
groupCount = numel(cutGroups);
startCutIndex = max(1, min(round(double(options.startCutIndex)), groupCount + 1));
result = localRunResult("finished", groupCount + 1, ...
    localRowTarget(cutGroups(end).rows(end, :), "exit"), groupCount);
laserOutputIsActive = [];

if startCutIndex > groupCount
    return;
end

try
    localSafeOutputsOff(true);

    for cutIndex = startCutIndex:groupCount
        if options.shouldStopFcn()
            result = localRunResult("stopped", cutIndex, localCurrentPositionTarget(state), cutIndex - 1);
            return;
        end

        groupRows = cutGroups(cutIndex).rows;
        leadTarget = localRowTarget(groupRows(1, :), "lead");
        startTarget = localRowTarget(groupRows(1, :), "start");
        exitTarget = localRowTarget(groupRows(end, :), "exit");

        localUpdateProgress(cutIndex, leadTarget, "Moving");
        moveOptions = struct( ...
            'shouldStopFcn', options.shouldStopFcn, ...
            'yieldFcn', options.yieldFcn, ...
            'pollIntervalSeconds', 0.02);
        [state, wasStopped] = lw_move_absolute(state, leadTarget, options.motion, moveOptions);
        localSafeOutputsOff();
        if wasStopped || options.shouldStopFcn()
            result = localRunResult("stopped", cutIndex, localCurrentPositionTarget(state), cutIndex - 1);
            return;
        end
        if options.pauseRequestedFcn()
            result = localRunResult("paused", cutIndex, leadTarget, cutIndex - 1);
            return;
        end

        if groupRows.pauseSeconds(1) > 0
            localUpdateProgress(cutIndex, leadTarget, "Settling");
            [wasStopped, wasPaused] = localPauseWithCallbacks(groupRows.pauseSeconds(1));
            if wasStopped
                result = localRunResult("stopped", cutIndex, leadTarget, cutIndex - 1);
                return;
            end
            if wasPaused
                result = localRunResult("paused", cutIndex, leadTarget, cutIndex - 1);
                return;
            end
        end

        lw_set_laser_power(state, groupRows.power(1));
        wasStopped = localRunCutStream(groupRows, leadTarget, startTarget, exitTarget);
        localSafeOutputsOff(true);

        if wasStopped || options.shouldStopFcn()
            result = localRunResult("stopped", cutIndex, localCurrentPositionTarget(state), cutIndex - 1);
            return;
        end

        state.currentPosition = exitTarget;
        localUpdateProgress(cutIndex, exitTarget, "Cut");

        if cutIndex < groupCount && options.pauseRequestedFcn()
            result = localRunResult("paused", cutIndex + 1, exitTarget, cutIndex);
            return;
        end

    end

    localSafeOutputsOff(true);
catch ME
    localSafeOutputsOff(true);
    rethrow(ME);
end

    function wasStopped = localRunCutStream(groupRows, leadTarget, startTarget, exitTarget)
        wasStopped = false;
        streams = struct();
        buffers = struct();
        triggerAxisName = localPulseTriggerAxisName(config);
        triggerChannel = localPulseTriggerChannel(config);

        try
            axisNames = {'x', 'y', 'z'};
            for axisIndex = 1:numel(axisNames)
                axisName = axisNames{axisIndex};
                deviceHandle = state.devices.(axisName);
                streams.(axisName) = deviceHandle.getStreams().getStream(1);
                buffers.(axisName) = deviceHandle.getStreams().getBuffer(1);
                streams.(axisName).disable();
                buffers.(axisName).erase();
                streams.(axisName).setupStore(buffers.(axisName), 1);
            end

            localAppendSegment(streams, leadTarget, startTarget, groupRows.leadSpeed(1));
            localAppendTriggerState(streams.(triggerAxisName), triggerChannel, true, config);
            for iSegment = 1:height(groupRows)
                segmentStart = localRowTarget(groupRows(iSegment, :), "start");
                segmentEnd = localRowTarget(groupRows(iSegment, :), "end");
                localAppendSegment(streams, segmentStart, segmentEnd, groupRows.scanSpeed(iSegment));
            end
            localAppendTriggerState(streams.(triggerAxisName), triggerChannel, false, config);
            localAppendSegment(streams, localRowTarget(groupRows(end, :), "end"), exitTarget, groupRows.leadSpeed(1));
            localAppendTriggerState(streams.(triggerAxisName), triggerChannel, false, config);

            streamFields = fieldnames(streams);
            for fieldIndex = 1:numel(streamFields)
                streams.(streamFields{fieldIndex}).disable();
            end
            for fieldIndex = 1:numel(streamFields)
                streams.(streamFields{fieldIndex}).setupLive(1);
            end

            localNotifyLaserState(true);
            for fieldIndex = 1:numel(streamFields)
                streams.(streamFields{fieldIndex}).call(buffers.(streamFields{fieldIndex}));
            end

            while localAnyAxisBusy(state)
                options.yieldFcn();
                if options.shouldStopFcn()
                    wasStopped = true;
                    try
                        lw_stop_motion(state);
                    catch
                    end
                    break;
                end
                pause(0.01);
            end

            localDisableStreams(streams);
            try
                state.currentPosition = lw_get_position(state);
            catch
                state.currentPosition = exitTarget;
            end
        catch ME
            localDisableStreams(streams);
            rethrow(ME);
        end
    end

    function localAppendSegment(streams, fromTarget, toTarget, speedMmPerSecond)
        distanceMm = localDistanceMm(fromTarget, toTarget);
        if distanceMm <= 1e-12
            return;
        end
        durationSeconds = distanceMm / speedMmPerSecond;
        localAppendAxisAction(streams.x, toTarget.x - fromTarget.x, toTarget.x, durationSeconds);
        localAppendAxisAction(streams.y, toTarget.y - fromTarget.y, toTarget.y, durationSeconds);
        localAppendAxisAction(streams.z, toTarget.z - fromTarget.z, toTarget.z, durationSeconds);
    end

    function localUpdateProgress(index, target, phase)
        if isempty(options.progressFcn)
            return;
        end
        options.progressFcn(index, groupCount, target, phase);
    end

    function [wasStopped, wasPaused] = localPauseWithCallbacks(seconds)
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
end

function localAppendAxisAction(streamHandle, deltaMm, targetValueMm, durationSeconds)
if abs(deltaMm) <= 1e-9
    localAppendWait(streamHandle, durationSeconds);
    return;
end

speedMmPerSecond = max(abs(deltaMm) / durationSeconds, 1e-5);
streamHandle.setMaxSpeed(speedMmPerSecond, zaber.motion.Units.VELOCITY_MILLIMETRES_PER_SECOND);
localAppendLine(streamHandle, targetValueMm);
end

function localAppendLine(streamHandle, targetValueMm)
measurementValue = zaber.motion.Measurement( ...
    targetValueMm, zaber.motion.Units.LENGTH_MILLIMETRES);
measurementArray = javaArray('zaber.motion.Measurement', 1);
measurementArray(1) = measurementValue;
try
    streamHandle.lineAbsolute(measurementArray, false);
catch
    streamHandle.lineAbsolute(measurementArray);
end
end

function localAppendWait(streamHandle, durationSeconds)
if durationSeconds <= 0
    return;
end
streamHandle.wait(durationSeconds, zaber.motion.Units.TIME_SECONDS);
end

function localAppendTriggerState(streamHandle, channelNumber, isActive, config)
action = lw_stage_pulse_trigger_action(isActive, config);
streamHandle.setDigitalOutput(channelNumber, action);
end

function localDisableStreams(streamStruct)
if isempty(fieldnames(streamStruct))
    return;
end
streamFields = fieldnames(streamStruct);
for fieldIndex = 1:numel(streamFields)
    try
        streamStruct.(streamFields{fieldIndex}).disable();
    catch
    end
end
end

function tf = localAnyAxisBusy(state)
tf = false;
axisNames = {'x', 'y', 'z'};
for i = 1:numel(axisNames)
    axisName = axisNames{i};
    if ~isfield(state.axes, axisName) || isempty(state.axes.(axisName))
        continue;
    end
    try
        if state.axes.(axisName).isBusy()
            tf = true;
            return;
        end
    catch
    end
end
end

function target = localRowTarget(row, targetName)
switch string(targetName)
    case "lead"
        target = struct('x', row.leadX, 'y', row.leadY, 'z', row.leadZ);
    case "start"
        target = struct('x', row.x, 'y', row.y, 'z', row.z);
    case "end"
        target = struct('x', row.x2, 'y', row.y2, 'z', row.z2);
    case "exit"
        target = struct('x', row.exitX, 'y', row.exitY, 'z', row.exitZ);
    otherwise
        error('Unsupported cut target: %s', char(targetName));
end
end

function result = localRunResult(status, nextCutIndex, returnTarget, lastCompletedIndex)
result = struct( ...
    'status', string(status), ...
    'nextCutIndex', nextCutIndex, ...
    'returnTarget', returnTarget, ...
    'lastCompletedIndex', lastCompletedIndex);
end

function target = localCurrentPositionTarget(state)
if isfield(state, 'currentPosition') && isstruct(state.currentPosition)
    target = state.currentPosition;
else
    target = struct('x', NaN, 'y', NaN, 'z', NaN);
end
end

function distanceMm = localDistanceMm(positionA, positionB)
distanceMm = sqrt( ...
    (positionA.x - positionB.x) ^ 2 + ...
    (positionA.y - positionB.y) ^ 2 + ...
    (positionA.z - positionB.z) ^ 2);
end

function axisName = localPulseTriggerAxisName(config)
if isfield(config.stage, 'pulseTriggerAxis')
    axisName = lower(char(config.stage.pulseTriggerAxis));
elseif isfield(config.stage, 'shutterAxis')
    axisName = lower(char(config.stage.shutterAxis));
else
    error('Pulse trigger axis is not configured.');
end

if ~ismember(axisName, {'x', 'y', 'z'})
    error('Pulse trigger axis must be x, y, or z.');
end
end

function channelNumber = localPulseTriggerChannel(config)
if isfield(config.stage, 'pulseTriggerChannel')
    channelNumber = config.stage.pulseTriggerChannel;
elseif isfield(config.stage, 'shutterChannel')
    channelNumber = config.stage.shutterChannel;
else
    error('Pulse trigger channel is not configured.');
end

channelNumber = double(channelNumber);
if ~isscalar(channelNumber) || ~isfinite(channelNumber) || channelNumber < 1
    error('Pulse trigger channel must be a positive integer.');
end
end
