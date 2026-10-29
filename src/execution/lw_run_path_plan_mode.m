function [state, result] = lw_run_path_plan_mode(state, config, trajectory, options)
%LW_RUN_PATH_PLAN_MODE Execute canonical path groups with explicit laser state.

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
if ~isfield(options, 'startPathGroupIndex') || isempty(options.startPathGroupIndex)
    options.startPathGroupIndex = 1;
end

if ~isfield(trajectory, 'writingPlan') || ~istable(trajectory.writingPlan)
    error('Path Plan Mode requires a loaded canonical writing plan.');
end

pathGroups = lw_validate_path_plan_for_run(trajectory.writingPlan);
groupCount = numel(pathGroups);
startPathGroupIndex = max(1, min( ...
    round(double(options.startPathGroupIndex)), groupCount + 1));
finalTarget = localRowTarget(pathGroups(end).rows(end, :), "end");
result = localRunResult("finished", groupCount + 1, finalTarget, groupCount);
laserOutputIsActive = [];

if startPathGroupIndex > groupCount
    return;
end

try
    localSafeOutputsOff(true);
    for groupIndex = startPathGroupIndex:groupCount
        if options.shouldStopFcn()
            result = localRunResult( ...
                "stopped", groupIndex, localCurrentPositionTarget(state), groupIndex - 1);
            return;
        end

        rows = pathGroups(groupIndex).rows;
        startTarget = localRowTarget(rows(1, :), "start");
        endTarget = localRowTarget(rows(end, :), "end");
        localUpdateProgress(groupIndex, startTarget, "Moving");
        moveOptions = struct( ...
            'shouldStopFcn', options.shouldStopFcn, ...
            'yieldFcn', options.yieldFcn, ...
            'pollIntervalSeconds', 0.02);
        [state, wasStopped] = lw_move_absolute( ...
            state, startTarget, options.motion, moveOptions);
        localSafeOutputsOff();
        if wasStopped || options.shouldStopFcn()
            result = localRunResult( ...
                "stopped", groupIndex, localCurrentPositionTarget(state), groupIndex - 1);
            return;
        end
        if options.pauseRequestedFcn()
            result = localRunResult("paused", groupIndex, startTarget, groupIndex - 1);
            return;
        end

        if rows.pauseSeconds(1) > 0
            localUpdateProgress(groupIndex, startTarget, "Settling");
            [wasStopped, wasPaused] = localPauseWithCallbacks(rows.pauseSeconds(1));
            if wasStopped
                result = localRunResult("stopped", groupIndex, startTarget, groupIndex - 1);
                return;
            end
            if wasPaused
                result = localRunResult("paused", groupIndex, startTarget, groupIndex - 1);
                return;
            end
        end

        lw_set_laser_power(state, rows.power(1));
        wasStopped = localRunPathStream(rows, endTarget);
        localSafeOutputsOff(true);
        if wasStopped || options.shouldStopFcn()
            result = localRunResult( ...
                "stopped", groupIndex, localCurrentPositionTarget(state), groupIndex - 1);
            return;
        end

        state.currentPosition = endTarget;
        localUpdateProgress(groupIndex, endTarget, "Path");
        if groupIndex < groupCount && options.pauseRequestedFcn()
            result = localRunResult("paused", groupIndex + 1, endTarget, groupIndex);
            return;
        end
    end
    localSafeOutputsOff(true);
catch ME
    localSafeOutputsOff(true);
    rethrow(ME);
end

    function wasStopped = localRunPathStream(rows, endTarget)
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

            gateIsOn = false;
            for segmentIndex = 1:height(rows)
                requestedGate = string(rows.laserState(segmentIndex)) == "on";
                if requestedGate ~= gateIsOn
                    localAppendTriggerState( ...
                        streams.(triggerAxisName), triggerChannel, requestedGate, config);
                    gateIsOn = requestedGate;
                end
                localAppendSegment(streams, ...
                    localRowTarget(rows(segmentIndex, :), "start"), ...
                    localRowTarget(rows(segmentIndex, :), "end"), ...
                    rows.speed(segmentIndex));
            end
            if gateIsOn
                localAppendTriggerState( ...
                    streams.(triggerAxisName), triggerChannel, false, config);
            end

            streamFields = fieldnames(streams);
            for fieldIndex = 1:numel(streamFields)
                streams.(streamFields{fieldIndex}).disable();
            end
            for fieldIndex = 1:numel(streamFields)
                streams.(streamFields{fieldIndex}).setupLive(1);
            end
            localNotifyLaserState(any(string(rows.laserState) == "on"));
            for fieldIndex = 1:numel(streamFields)
                streams.(streamFields{fieldIndex}).call( ...
                    buffers.(streamFields{fieldIndex}));
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
                state.currentPosition = endTarget;
            end
        catch ME
            localDisableStreams(streams);
            rethrow(ME);
        end
    end

    function localAppendSegment(streams, fromTarget, toTarget, speedMmPerSecond)
        distanceMm = localDistanceMm(fromTarget, toTarget);
        durationSeconds = distanceMm / speedMmPerSecond;
        localAppendAxisAction(streams.x, toTarget.x - fromTarget.x, ...
            toTarget.x, durationSeconds);
        localAppendAxisAction(streams.y, toTarget.y - fromTarget.y, ...
            toTarget.y, durationSeconds);
        localAppendAxisAction(streams.z, toTarget.z - fromTarget.z, ...
            toTarget.z, durationSeconds);
    end

    function localUpdateProgress(index, target, phase)
        if ~isempty(options.progressFcn)
            options.progressFcn(index, groupCount, target, phase);
        end
    end

    function [wasStopped, wasPaused] = localPauseWithCallbacks(seconds)
        wasStopped = false;
        wasPaused = false;
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
            pause(max(min(seconds - toc(timerStart), 0.02), 0));
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
        if ~isempty(options.laserStateFcn)
            options.laserStateFcn(logical(isOn));
        end
    end
end

function localAppendAxisAction(streamHandle, deltaMm, targetValueMm, durationSeconds)
if abs(deltaMm) <= 1e-9
    streamHandle.wait(durationSeconds, zaber.motion.Units.TIME_SECONDS);
    return;
end
speedMmPerSecond = max(abs(deltaMm) / durationSeconds, 1e-5);
streamHandle.setMaxSpeed( ...
    speedMmPerSecond, zaber.motion.Units.VELOCITY_MILLIMETRES_PER_SECOND);
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

function localAppendTriggerState(streamHandle, channelNumber, isActive, config)
action = lw_stage_pulse_trigger_action(isActive, config);
streamHandle.setDigitalOutput(channelNumber, action);
end

function localDisableStreams(streamStruct)
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
for axisIndex = 1:numel(axisNames)
    axisName = axisNames{axisIndex};
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
if string(targetName) == "start"
    target = struct('x', row.x, 'y', row.y, 'z', row.z);
else
    target = struct('x', row.x2, 'y', row.y2, 'z', row.z2);
end
end

function result = localRunResult(status, nextPathGroupIndex, returnTarget, lastCompletedIndex)
result = struct( ...
    'status', string(status), ...
    'nextPathGroupIndex', nextPathGroupIndex, ...
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
