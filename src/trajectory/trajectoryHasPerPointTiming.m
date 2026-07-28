function tf = trajectoryHasPerPointTiming(trajectory)
%TRAJECTORYHASPERPOINTTIMING True for point writing plans with dwell/pause rows.

tf = false;
if isempty(trajectory) || ~isstruct(trajectory) || ...
        ~isfield(trajectory, 'writingPlan') || ~istable(trajectory.writingPlan) || ...
        height(trajectory.writingPlan) == 0
    return;
end

requiredNames = {'operation', 'dwell', 'pauseSeconds'};
if ~all(ismember(requiredNames, trajectory.writingPlan.Properties.VariableNames))
    return;
end

tf = all(string(trajectory.writingPlan.operation) == "point");
end
