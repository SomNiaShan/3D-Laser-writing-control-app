function wasStopped = lw_manual_exposure(state, config, powerPercent, exposureTimeSeconds, laserStateFcn, shouldStopFcn, yieldFcn)
%LW_MANUAL_EXPOSURE Hold the pulse trigger high for a timed exposure.

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

lw_set_laser_power(state, powerPercent);
lw_set_stage_pulse_trigger(state, true, config);
notifyLaserState(true);

try
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
