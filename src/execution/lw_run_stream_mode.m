function state = lw_run_stream_mode(state, config, trajectory, options)
%LW_RUN_STREAM_MODE Execute stream-capable fixed-power writing with queued TTL switching.

if nargin < 4 || isempty(options)
    options = struct();
end
if ~isfield(options, 'motion') || isempty(options.motion)
    options.motion = struct( ...
        'velocity', config.motion.defaultVelocity, ...
        'acceleration', config.motion.defaultAcceleration);
end
if ~isfield(options, 'targetSpeedMmPerSecond')
    options.targetSpeedMmPerSecond = config.execution.streamTargetSpeed;
end
if ~isfield(options, 'powerPercent')
    options.powerPercent = trajectory.power(1);
end
if ~isfield(options, 'ttlGateWidthUs')
    options.ttlGateWidthUs = config.stage.ttlGateWidthUs;
end
options.ttlGateWidthUs = lw_validate_stage_schedule_duration_us( ...
    options.ttlGateWidthUs, config, 'TTL Gate Width', false);
if ~isfield(options, 'pulseTimesSeconds') || isempty(options.pulseTimesSeconds)
    options.pulseTimesSeconds = localPulseTimes(trajectory, options.targetSpeedMmPerSecond);
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

import zaber.motion.Units;

streams = struct();
buffers = struct();
triggerAxisName = localPulseTriggerAxisName(config);
triggerChannel = localPulseTriggerChannel(config);

preMoveTarget = struct( ...
    'x', trajectory.x(1), ...
    'y', trajectory.y(1), ...
    'z', trajectory.z(1));

moveOptions = struct( ...
    'shouldStopFcn', options.shouldStopFcn, ...
    'yieldFcn', options.yieldFcn, ...
    'pollIntervalSeconds', 0.02);

try
    localSafeOutputsOff();

    if options.shouldStopFcn()
        return;
    end

    [state, wasStopped] = lw_move_absolute(state, preMoveTarget, options.motion, moveOptions);
    if wasStopped || options.shouldStopFcn()
        localSafeOutputsOff();
        return;
    end

    lw_set_laser_power(state, options.powerPercent);

    axisNames = {'x', 'y', 'z'};
    for i = 1:numel(axisNames)
        axisName = axisNames{i};
        deviceHandle = state.devices.(axisName);
        streams.(axisName) = deviceHandle.getStreams().getStream(1);
        buffers.(axisName) = deviceHandle.getStreams().getBuffer(1);
        streams.(axisName).disable();
        buffers.(axisName).erase();
        streams.(axisName).setupStore(buffers.(axisName), 1);
    end

    localAppendPulse(streams.(triggerAxisName), triggerChannel, ...
        options.ttlGateWidthUs, config);

    for i = 2:numel(trajectory.x)
        dx = trajectory.x(i) - trajectory.x(i - 1);
        dy = trajectory.y(i) - trajectory.y(i - 1);
        dz = trajectory.z(i) - trajectory.z(i - 1);
        ds = sqrt(dx ^ 2 + dy ^ 2 + dz ^ 2);
        if ds < 1e-9
            continue;
        end
        dt = ds / options.targetSpeedMmPerSecond;

        localAppendAxisAction(streams.x, dx, trajectory.x(i), dt);
        localAppendAxisAction(streams.y, dy, trajectory.y(i), dt);
        localAppendAxisAction(streams.z, dz, trajectory.z(i), dt);

        localAppendPulse(streams.(triggerAxisName), triggerChannel, ...
            options.ttlGateWidthUs, config);
    end

    localAppendTriggerState(streams.(triggerAxisName), triggerChannel, false, config);

    fields = fieldnames(streams);
    for i = 1:numel(fields)
        streams.(fields{i}).disable();
    end
    for i = 1:numel(fields)
        streams.(fields{i}).setupLive(1);
    end

    for i = 1:numel(fields)
        streams.(fields{i}).call(buffers.(fields{i}));
    end

    localUpdateProgress(1, preMoveTarget);
    timerStart = tic;
    lastIndex = 1;
    stopIssued = false;
    finalTarget = struct( ...
        'x', trajectory.x(end), ...
        'y', trajectory.y(end), ...
        'z', trajectory.z(end));
    completionToleranceMm = localCompletionToleranceMm(trajectory);

    while localAnyAxisBusy(state)
        options.yieldFcn();

        elapsedSeconds = toc(timerStart);
        currentIndex = find(options.pulseTimesSeconds <= elapsedSeconds, 1, 'last');
        if isempty(currentIndex)
            currentIndex = 1;
        end
        currentIndex = min(currentIndex, numel(trajectory.x));

        actualPosition = [];
        try
            actualPosition = lw_get_position(state);
            state.currentPosition = actualPosition;
            if localDistanceMm(actualPosition, finalTarget) <= completionToleranceMm
                currentIndex = numel(trajectory.x);
            end
        catch
        end

        if currentIndex ~= lastIndex
            lastIndex = currentIndex;
            localUpdateProgress(currentIndex, actualPosition);
        end

        if options.shouldStopFcn()
            stopIssued = true;
            lw_stop_motion(state);
            break;
        end

        pause(0.01);
    end

    if ~stopIssued && lastIndex < numel(trajectory.x)
        localUpdateProgress(numel(trajectory.x), finalTarget);
    end

    localDisableStreams(streams);
    localSafeOutputsOff();
catch ME
    localDisableStreams(streams);
    localSafeOutputsOff();
    rethrow(ME);
end

    function localUpdateProgress(index, actualPosition)
        if isempty(options.progressFcn)
            return;
        end
        if nargin < 2 || isempty(actualPosition)
            target = struct( ...
                'x', trajectory.x(index), ...
                'y', trajectory.y(index), ...
                'z', trajectory.z(index));
        else
            target = actualPosition;
        end
        options.progressFcn(index, numel(trajectory.x), target, "Stream");
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

    function localSafeOutputsOff()
        try
            lw_set_stage_pulse_trigger(state, false, config);
        catch
        end
        try
            lw_set_laser_power(state, 0);
        catch
        end
    end
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

function localAppendAxisAction(streamHandle, deltaMm, targetValueMm, durationSeconds)
if abs(deltaMm) <= 1e-9
    localAppendWait(streamHandle, durationSeconds);
    return;
end

speedMmPerSecond = max(abs(deltaMm) / durationSeconds, 1e-5);
streamHandle.setMaxSpeed(speedMmPerSecond, zaber.motion.Units.VELOCITY_MILLIMETRES_PER_SECOND);
localAppendLine(streamHandle, targetValueMm);
end

function localAppendWait(streamHandle, durationSeconds)
if durationSeconds <= 0
    return;
end
streamHandle.wait(durationSeconds, zaber.motion.Units.TIME_SECONDS);
end

function localAppendPulse(streamHandle, channelNumber, pulseWidthUs, config)
streamHandle.getIo().setDigitalOutputSchedule( ...
    channelNumber, ...
    lw_stage_pulse_trigger_action(true, config), ...
    lw_stage_pulse_trigger_action(false, config), ...
    pulseWidthUs, ...
    zaber.motion.Units.TIME_MICROSECONDS);
end

function localAppendTriggerState(streamHandle, channelNumber, isActive, config)
action = lw_stage_pulse_trigger_action(isActive, config);
streamHandle.setDigitalOutput(channelNumber, action);
end

function pulseTimesSeconds = localPulseTimes(trajectory, targetSpeedMmPerSecond)
pointCount = numel(trajectory.x);
pulseTimesSeconds = zeros(pointCount, 1);
if pointCount < 2
    return;
end

dx = diff(trajectory.x(:));
dy = diff(trajectory.y(:));
dz = diff(trajectory.z(:));
segmentLengths = sqrt(dx .^ 2 + dy .^ 2 + dz .^ 2);
pulseTimesSeconds(2:end) = cumsum(segmentLengths ./ targetSpeedMmPerSecond);
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

function distanceMm = localDistanceMm(positionA, positionB)
distanceMm = sqrt( ...
    (positionA.x - positionB.x) ^ 2 + ...
    (positionA.y - positionB.y) ^ 2 + ...
    (positionA.z - positionB.z) ^ 2);
end

function toleranceMm = localCompletionToleranceMm(trajectory)
toleranceMm = 0.001;
if numel(trajectory.x) < 2
    return;
end

dx = diff(trajectory.x(:));
dy = diff(trajectory.y(:));
dz = diff(trajectory.z(:));
segmentLengths = sqrt(dx .^ 2 + dy .^ 2 + dz .^ 2);
segmentLengths = segmentLengths(segmentLengths > 0);
if isempty(segmentLengths)
    return;
end

toleranceMm = max(min(segmentLengths) * 0.25, toleranceMm);
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
