function [trajectory, timing] = lw_prepare_point_run_trajectory( ...
        trajectory, defaultDwellSeconds, defaultSettleSeconds, config)
%LW_PREPARE_POINT_RUN_TRAJECTORY Resolve canonical per-point timing values.

if isempty(trajectory) || ~isstruct(trajectory) || ~isfield(trajectory, 'x') || ...
        isempty(trajectory.x)
    error('No point trajectory is loaded.');
end

if isfield(trajectory, 'writingPlan') && istable(trajectory.writingPlan)
    [trajectory, dwellSeconds, settleSeconds] = localFromWritingPlan(trajectory);
    timingSource = "writing_plan";
elseif isfield(trajectory, 'dwellSeconds') && ...
        isfield(trajectory, 'preWritePauseSeconds')
    dwellSeconds = double(trajectory.dwellSeconds(:));
    settleSeconds = double(trajectory.preWritePauseSeconds(:));
    timingSource = localStoredTimingSource(trajectory);
else
    pointCount = numel(trajectory.x);
    defaultDwellSeconds = localNonnegativeScalar(defaultDwellSeconds, 'Default point dwell');
    defaultSettleSeconds = localNonnegativeScalar(defaultSettleSeconds, 'Default pre-write settle');
    dwellSeconds = repmat(defaultDwellSeconds, pointCount, 1);
    settleSeconds = repmat(defaultSettleSeconds, pointCount, 1);
    timingSource = "ui_defaults";
end

pointCount = numel(trajectory.x);
if numel(dwellSeconds) ~= pointCount || numel(settleSeconds) ~= pointCount
    error('Point timing values must match the number of trajectory points.');
end
if any(~isfinite(settleSeconds) | settleSeconds < 0)
    error('Point pause_s values must be finite and nonnegative.');
end

limits = lw_stage_digital_output_schedule_limits(config);
requestedDwellUs = dwellSeconds .* 1e6;
autoRoundedMask = false(size(requestedDwellUs));
autoRoundAdjustmentUs = zeros(size(requestedDwellUs));
if timingSource == "writing_plan"
    [requestedDwellUs, autoRoundedMask, autoRoundAdjustmentUs] = ...
        localRoundWritingPlanDwellUs(requestedDwellUs, limits);
end

dwellUs = lw_validate_stage_schedule_duration_us( ...
    requestedDwellUs, config, 'Point dwell_s', true);
dwellSeconds = dwellUs .* 1e-6;
trajectory.dwellSeconds = dwellSeconds;
trajectory.preWritePauseSeconds = settleSeconds;
if timingSource == "writing_plan"
    trajectory.writingPlan.dwell = dwellSeconds;
end
if ~isfield(trajectory, 'meta') || ~isstruct(trajectory.meta)
    trajectory.meta = struct();
end
trajectory.meta.pointTimingSource = timingSource;

if any(autoRoundedMask)
    maxAutoRoundAdjustmentUs = max(abs(autoRoundAdjustmentUs(autoRoundedMask)));
else
    maxAutoRoundAdjustmentUs = 0;
end
timing = struct( ...
    'executionMode', "timed_dwell", ...
    'gateMethod', "zaber_digital_output_schedule", ...
    'pauseSemantics', "pre_write_settle", ...
    'source', timingSource, ...
    'pointCount', pointCount, ...
    'dwellMicrosecondsMin', min(dwellUs), ...
    'dwellMicrosecondsMax', max(dwellUs), ...
    'preWritePauseSecondsMin', min(settleSeconds), ...
    'preWritePauseSecondsMax', max(settleSeconds), ...
    'zeroDwellPointCount', nnz(dwellUs == 0), ...
    'dwellAutoRoundedPointCount', nnz(autoRoundedMask), ...
    'dwellAutoRoundMaxAdjustmentUs', maxAutoRoundAdjustmentUs, ...
    'hardwareScheduleMinimumUs', limits.minimumUs, ...
    'hardwareScheduleResolutionUs', limits.resolutionUs);
end

function [roundedUs, adjustedMask, adjustmentUs] = ...
        localRoundWritingPlanDwellUs(valuesUs, limits)
roundedUs = valuesUs;
adjustedMask = false(size(valuesUs));
adjustmentUs = zeros(size(valuesUs));

positiveMask = valuesUs > 0;
stepValues = valuesUs ./ limits.resolutionUs;
nearestSteps = round(stepValues);
nearestUs = nearestSteps .* limits.resolutionUs;
stepTolerance = 1e-9 .* max(1, abs(stepValues));
onGrid = abs(stepValues - nearestSteps) <= stepTolerance;

% Preserve genuinely sub-minimum values so the strict validator still
% rejects them. Values that only differ from the grid by floating-point
% roundoff are safe to normalize before applying the minimum.
minimumComparisonUs = valuesUs;
minimumComparisonUs(positiveMask & onGrid) = nearestUs(positiveMask & onGrid);
belowMinimum = positiveMask & minimumComparisonUs < limits.minimumUs;
roundableMask = positiveMask & ~belowMinimum;

roundedUs(roundableMask) = nearestUs(roundableMask);
adjustedMask = roundableMask & ~onGrid;
adjustmentUs(adjustedMask) = roundedUs(adjustedMask) - valuesUs(adjustedMask);
end

function [trajectory, dwellSeconds, settleSeconds] = localFromWritingPlan(trajectory)
plan = trajectory.writingPlan;
if isempty(plan) || height(plan) == 0
    error('Point Mode requires at least one writing-plan row.');
end

requiredNames = {'operation', 'x', 'y', 'z', 'power', 'dwell', 'pauseSeconds'};
missingNames = setdiff(requiredNames, plan.Properties.VariableNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan is missing internal Point Mode columns: %s.', ...
        strjoin(missingNames, ', '));
end

operationValues = string(plan.operation);
badModeIndex = find(operationValues ~= "point", 1, 'first');
if ~isempty(badModeIndex)
    error('lw:PointModeMixedPlan', ...
        ['Point Mode requires every writing-plan row to use operation=point; ', ...
        'row %d uses operation=%s.'], badModeIndex, char(operationValues(badModeIndex)));
end

trajectory.x = double(plan.x(:));
trajectory.y = double(plan.y(:));
trajectory.z = double(plan.z(:));
trajectory.power = double(plan.power(:));
dwellSeconds = double(plan.dwell(:));
settleSeconds = double(plan.pauseSeconds(:));
end

function timingSource = localStoredTimingSource(trajectory)
timingSource = "trajectory";
if isfield(trajectory, 'meta') && isstruct(trajectory.meta) && ...
        isfield(trajectory.meta, 'pointTimingSource')
    timingSource = string(trajectory.meta.pointTimingSource);
end
end

function value = localNonnegativeScalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value < 0
    error('%s must be a finite nonnegative scalar.', label);
end
value = double(value);
end
