function tf = trajectoryHasPerPointTiming(trajectory)
%TRAJECTORYHASPERPOINTTIMING True for point writing plans with dwell/pause rows.

tf = false;
if isempty(trajectory) || ~isstruct(trajectory) || ...
        ~isfield(trajectory, 'cutPlan') || ~istable(trajectory.cutPlan) || ...
        height(trajectory.cutPlan) == 0
    return;
end

requiredNames = {'mode', 'dwell', 'pauseSeconds'};
if ~all(ismember(requiredNames, trajectory.cutPlan.Properties.VariableNames))
    return;
end

tf = all(string(trajectory.cutPlan.mode) == "point");
end
