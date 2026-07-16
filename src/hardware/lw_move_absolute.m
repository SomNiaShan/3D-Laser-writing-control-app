function [state, wasStopped] = lw_move_absolute(state, target, motion, options)
%LW_MOVE_ABSOLUTE Move all three axes to an absolute target.

import zaber.motion.*;

if nargin < 4 || isempty(options)
    options = struct();
end
if ~isfield(options, 'shouldStopFcn')
    options.shouldStopFcn = [];
end
if ~isfield(options, 'yieldFcn')
    options.yieldFcn = @() drawnow;
end
if ~isfield(options, 'pollIntervalSeconds')
    options.pollIntervalSeconds = 0.02;
end

wasStopped = false;
busyPollOptions = struct( ...
    'maxRetries', 3, ...
    'retryDelaySeconds', max(0.05, options.pollIntervalSeconds));

state.axes.x.moveAbsolute( ...
    target.x, Units.LENGTH_MILLIMETRES, false, ...
    motion.velocity.x, Units.VELOCITY_MILLIMETRES_PER_SECOND, ...
    motion.acceleration.x, Units.ACCELERATION_MILLIMETRES_PER_SECOND_SQUARED);

state.axes.y.moveAbsolute( ...
    target.y, Units.LENGTH_MILLIMETRES, false, ...
    motion.velocity.y, Units.VELOCITY_MILLIMETRES_PER_SECOND, ...
    motion.acceleration.y, Units.ACCELERATION_MILLIMETRES_PER_SECOND_SQUARED);

state.axes.z.moveAbsolute( ...
    target.z, Units.LENGTH_MILLIMETRES, false, ...
    motion.velocity.z, Units.VELOCITY_MILLIMETRES_PER_SECOND, ...
    motion.acceleration.z, Units.ACCELERATION_MILLIMETRES_PER_SECOND_SQUARED);

axisList = {state.axes.x, state.axes.y, state.axes.z};
while any(cellfun(@(axisHandle) lw_axis_is_busy(axisHandle, busyPollOptions), axisList))
    options.yieldFcn();
    if ~isempty(options.shouldStopFcn) && options.shouldStopFcn()
        for i = 1:numel(axisList)
            try
                axisList{i}.stop(false);
            catch
            end
        end
        wasStopped = true;
        try
            state.currentPosition = lw_get_position(state);
        catch
        end
        return;
    end
    pause(options.pollIntervalSeconds);
end

try
    state.currentPosition = lw_get_position(state);
catch
    state.currentPosition = target;
end
end
