function wasStopped = lw_manual_exposure(state, config, powerPercent, exposureTimeSeconds, laserStateFcn, shouldStopFcn, yieldFcn)
%LW_MANUAL_EXPOSURE Run a firmware-timed Zaber digital-output exposure.

if nargin < 5
    laserStateFcn = [];
end
if nargin < 6
    shouldStopFcn = [];
end
if nargin < 7 || isempty(yieldFcn)
    yieldFcn = @() drawnow;
end

wasStopped = false;

if ~isempty(shouldStopFcn) && shouldStopFcn()
    wasStopped = true;
    return;
end

exposureUs = lw_validate_stage_schedule_duration_us( ...
    double(exposureTimeSeconds) .* 1e6, config, 'Exposure duration', true);
exposureTimeSeconds = exposureUs .* 1e-6;
if isequal(exposureTimeSeconds, 0)
    notifyLaserState(false);
    return;
end

lw_set_laser_power(state, powerPercent);
try
    exposureTimeSeconds = lw_schedule_stage_pulse_trigger( ...
        state, exposureTimeSeconds, config);
    notifyLaserState(true);
    timerStart = tic;
    while toc(timerStart) < exposureTimeSeconds
        yieldFcn();
        if ~isempty(shouldStopFcn) && shouldStopFcn()
            wasStopped = true;
            break;
        end
        remainingSeconds = exposureTimeSeconds - toc(timerStart);
        pause(max(min(remainingSeconds, 0.02), 0));
    end
catch ME
    safeLaserOff();
    rethrow(ME);
end

safeLaserOff();

    function notifyLaserState(isOn)
        if ~isempty(laserStateFcn)
            laserStateFcn(logical(isOn));
        end
    end

    function safeLaserOff()
        try
            lw_set_stage_pulse_trigger(state, false, config);
        catch
        end
        notifyLaserState(false);
    end
end
