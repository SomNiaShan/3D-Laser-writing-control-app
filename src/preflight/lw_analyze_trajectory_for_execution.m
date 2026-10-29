function analysis = lw_analyze_trajectory_for_execution(traj, limits, yDisplayReference)
%LW_ANALYZE_TRAJECTORY_FOR_EXECUTION Summarize bounds and power for a run.

if isempty(traj) || isempty(traj.x)
    error('No plan is loaded.');
end

xValues = traj.x(:);
yStageValues = traj.y(:);
zValues = traj.z(:);
operationCount = numel(xValues);

if isfield(traj, 'writingPlan') && istable(traj.writingPlan)
    [pathX, pathY, pathZ] = localPathEndValues(traj.writingPlan);
    xValues = [xValues; pathX];
    yStageValues = [yStageValues; pathY];
    zValues = [zValues; pathZ];
end

yDisplayValues = yDisplayReference - yStageValues;

analysis = struct();
analysis.pointCount = operationCount;
analysis.xRange = [min(xValues), max(xValues)];
analysis.yDisplayRange = [min(yDisplayValues), max(yDisplayValues)];
analysis.zRange = [min(zValues), max(zValues)];
analysis.boundingBoxSize = [ ...
    analysis.xRange(2) - analysis.xRange(1), ...
    analysis.yDisplayRange(2) - analysis.yDisplayRange(1), ...
    analysis.zRange(2) - analysis.zRange(1)];
analysis.xLimits = limits.x;
analysis.yDisplayLimits = sort(yDisplayReference - limits.y);
analysis.zLimits = limits.z;
analysis.powerSource = trajectoryPowerSource(traj);

powerValues = traj.power(:);
finitePowerValues = powerValues(isfinite(powerValues));
if isempty(finitePowerValues)
    analysis.powerRange = [nan, nan];
else
    analysis.powerRange = [min(finitePowerValues), max(finitePowerValues)];
end

analysis.inBounds = true;
analysis.firstViolation = struct('message', "");

idx = find(xValues < analysis.xLimits(1) | xValues > analysis.xLimits(2), 1, 'first');
if ~isempty(idx)
    analysis.inBounds = false;
    analysis.firstViolation.message = sprintf( ...
        'Run cancelled: point %d has X = %.3f mm, outside [%.3f, %.3f] mm.', ...
        idx, xValues(idx), analysis.xLimits(1), analysis.xLimits(2));
    return;
end

idx = find(zValues < analysis.zLimits(1) | zValues > analysis.zLimits(2), 1, 'first');
if ~isempty(idx)
    analysis.inBounds = false;
    analysis.firstViolation.message = sprintf( ...
        'Run cancelled: point %d has Z = %.3f mm, outside [%.3f, %.3f] mm.', ...
        idx, zValues(idx), analysis.zLimits(1), analysis.zLimits(2));
    return;
end

idx = find(yDisplayValues < analysis.yDisplayLimits(1) | ...
    yDisplayValues > analysis.yDisplayLimits(2), 1, 'first');
if ~isempty(idx)
    analysis.inBounds = false;
    analysis.firstViolation.message = sprintf( ...
        'Run cancelled: point %d has Y = %.3f mm, outside [%.3f, %.3f] mm.', ...
        idx, yDisplayValues(idx), analysis.yDisplayLimits(1), analysis.yDisplayLimits(2));
end
end

function [xValues, yValues, zValues] = localPathEndValues(writingPlan)
requiredNames = {'operation', 'x2', 'y2', 'z2'};
if ~all(ismember(requiredNames, writingPlan.Properties.VariableNames))
    xValues = [];
    yValues = [];
    zValues = [];
    return;
end
pathRows = string(writingPlan.operation) == "path";
finiteRows = pathRows & isfinite(writingPlan.x2) & ...
    isfinite(writingPlan.y2) & isfinite(writingPlan.z2);
xValues = writingPlan.x2(finiteRows);
yValues = writingPlan.y2(finiteRows);
zValues = writingPlan.z2(finiteRows);
end
