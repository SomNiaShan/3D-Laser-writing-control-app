function [wasStopped, completedCount] = lw_manual_exposure_stream( ...
        state, config, powerPercent, exposureTimeSeconds, repeatCount, ...
        intervalSeconds, laserStateFcn, progressFcn, shouldStopFcn, yieldFcn)
%LW_MANUAL_EXPOSURE_STREAM Run an entire repeat sequence in a Zaber stream.

if nargin < 7
    laserStateFcn = [];
end
if nargin < 8
    progressFcn = [];
end
if nargin < 9
    shouldStopFcn = [];
end
if nargin < 10 || isempty(yieldFcn)
    yieldFcn = @() drawnow;
end

wasStopped = false;
completedCount = 0;
if localShouldStop()
    wasStopped = true;
    return;
end

plan = lw_manual_exposure_stream_plan( ...
    exposureTimeSeconds, repeatCount, intervalSeconds, config);
powerPercent = validatePowerPercent(powerPercent, 'Exposure power');
[axisHandle, channelNumber] = lw_resolve_stage_pulse_trigger(state, config);
axisName = localPulseTriggerAxisName(config);
axisNumber = localAxisNumber(config, axisName);
deviceHandle = axisHandle.getDevice();
streamId = localResourceId(config, 'manualExposureStreamId', 1, 'Manual Exposure stream ID');
bufferId = localResourceId(config, 'manualExposureBufferId', 1, 'Manual Exposure buffer ID');
localRequireStreamResource(deviceHandle, 'stream.numstreams', streamId, 'stream');
localRequireStreamResource(deviceHandle, 'stream.numbufs', bufferId, 'buffer');

streamHandle = [];
bufferHandle = [];
playbackStarted = false;
playbackCompleted = false;
cleanupObj = onCleanup(@localSafeCleanup);

lw_set_stage_pulse_trigger(state, false, config);
localNotifyLaserState(false);
localNotifyProgress(0);

streamHandle = deviceHandle.getStreams().getStream(streamId);
bufferHandle = deviceHandle.getStreams().getBuffer(bufferId);
streamHandle.disable();
bufferHandle.erase();
streamHandle.setupStore(bufferHandle, axisNumber);

streamIo = streamHandle.getIo();
activeAction = lw_stage_pulse_trigger_action(true, config);
inactiveAction = lw_stage_pulse_trigger_action(false, config);
for exposureIndex = 1:plan.repeatCount
    streamIo.setDigitalOutputSchedule( ...
        channelNumber, activeAction, inactiveAction, plan.exposureUs, ...
        zaber.motion.Units.TIME_MICROSECONDS);
    if exposureIndex < plan.repeatCount
        waitMilliseconds = plan.cycleWaitMilliseconds;
    else
        % Keep the stream alive until the last scheduled OFF has fired, then
        % append a direct safe state to cancel any still-pending action.
        waitMilliseconds = plan.finalWaitMilliseconds;
    end
    streamHandle.wait(waitMilliseconds, zaber.motion.Units.TIME_MILLISECONDS);

    if mod(exposureIndex, 25) == 0
        yieldFcn();
        if localShouldStop()
            wasStopped = true;
            return;
        end
    end
end
streamIo.setDigitalOutput(channelNumber, inactiveAction);

streamHandle.disable();
streamHandle.setupLive(axisNumber);
yieldFcn();
if localShouldStop()
    wasStopped = true;
    return;
end

% The analog power is written once. Only the stage-generated PP_EN gate is
% toggled by the stored exposure sequence.
lw_set_laser_power(state, powerPercent);
playbackStarted = true;
streamHandle.call(bufferHandle);
playbackTimer = tic;
localUpdateExpectedStatus(0);

while streamHandle.isBusy()
    yieldFcn();
    if localShouldStop()
        wasStopped = true;
        try
            lw_stop_motion(state);
        catch
        end
        break;
    end
    localUpdateExpectedStatus(toc(playbackTimer));
    pause(0.01);
end

if ~wasStopped
    playbackCompleted = true;
    completedCount = plan.repeatCount;
    localNotifyLaserState(false);
    localNotifyProgress(completedCount);
end

    function tf = localShouldStop()
        tf = ~isempty(shouldStopFcn) && logical(shouldStopFcn());
    end

    function localUpdateExpectedStatus(elapsedSeconds)
        [expectedLaserOn, expectedCompleted] = ...
            localExpectedSequenceStatus(elapsedSeconds, plan);
        localNotifyLaserState(expectedLaserOn);
        if expectedCompleted ~= completedCount
            completedCount = expectedCompleted;
            localNotifyProgress(completedCount);
        end
    end

    function localNotifyLaserState(isOn)
        if ~isempty(laserStateFcn)
            laserStateFcn(logical(isOn));
        end
    end

    function localNotifyProgress(value)
        if ~isempty(progressFcn)
            progressFcn(value);
        end
    end

    function localSafeCleanup()
        if playbackStarted && ~playbackCompleted %#ok<MOCUP>
            try
                lw_stop_motion(state);
            catch
            end
        end
        try
            lw_set_stage_pulse_trigger(state, false, config);
        catch
        end
        try
            lw_set_laser_power(state, 0);
        catch
        end
        try
            if ~isempty(streamHandle)
                streamHandle.disable();
            end
        catch
        end
        try
            if ~isempty(bufferHandle)
                bufferHandle.erase();
            end
        catch
        end
        try
            localNotifyLaserState(false);
        catch
        end
    end
end

function [laserIsOn, completedCount] = localExpectedSequenceStatus(elapsedSeconds, plan)
elapsedSeconds = max(0, double(elapsedSeconds));
if elapsedSeconds >= plan.expectedOpticalDurationSeconds
    laserIsOn = false;
    completedCount = plan.repeatCount;
    return;
end

if plan.repeatCount == 1
    laserIsOn = elapsedSeconds < plan.exposureSeconds;
    completedCount = double(~laserIsOn);
    return;
end

cycleSeconds = plan.cycleUs .* 1e-6;
cycleIndex = min(floor(elapsedSeconds ./ cycleSeconds), plan.repeatCount - 1);
phaseSeconds = elapsedSeconds - cycleIndex .* cycleSeconds;
laserIsOn = phaseSeconds < plan.exposureSeconds;
completedCount = cycleIndex + double(~laserIsOn);
end

function axisName = localPulseTriggerAxisName(config)
if ~isstruct(config) || ~isfield(config, 'stage') || ...
        ~isfield(config.stage, 'pulseTriggerAxis')
    error('Stage pulse trigger axis is not configured.');
end
axisName = lower(char(config.stage.pulseTriggerAxis));
if ~ismember(axisName, {'x', 'y', 'z'})
    error('Stage pulse trigger axis must be x, y, or z.');
end
end

function axisNumber = localAxisNumber(config, axisName)
if ~isfield(config.stage, 'axisMap') || ...
        ~isfield(config.stage.axisMap, axisName)
    error('Stage axis map is missing the pulse trigger axis "%s".', axisName);
end
axisNumber = positiveInteger( ...
    config.stage.axisMap.(axisName), 'Pulse trigger axis number');
end

function resourceId = localResourceId(config, fieldName, fallbackValue, label)
resourceId = fallbackValue;
if isfield(config, 'stage') && isfield(config.stage, fieldName)
    resourceId = config.stage.(fieldName);
end
resourceId = positiveInteger(resourceId, label);
end

function localRequireStreamResource(deviceHandle, settingName, requestedId, label)
try
    availableCount = double(deviceHandle.getSettings().getInt(settingName));
catch ME
    capabilityError = MException('lw:stage:StreamCapabilityUnavailable', ...
        'Unable to query Zaber %s support from %s.', label, settingName);
    capabilityError = addCause(capabilityError, ME);
    throw(capabilityError);
end
if availableCount < requestedId
    error('lw:stage:StreamResourceUnavailable', ...
        'Zaber device provides %d %s resource(s), but Manual Exposure requests ID %d.', ...
        availableCount, label, requestedId);
end
end
