function lw_stop_motion(state)
%LW_STOP_MOTION Best-effort stop for all connected stage axes.

if ~isfield(state, 'axes') || isempty(state.axes)
    return;
end

axisNames = {'x', 'y', 'z'};
for i = 1:numel(axisNames)
    axisName = axisNames{i};
    if ~isfield(state.axes, axisName) || isempty(state.axes.(axisName))
        continue;
    end
    try
        state.axes.(axisName).stop(false);
    catch
    end
end
end
