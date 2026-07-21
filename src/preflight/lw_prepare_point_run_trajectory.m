function [trajectory, timing] = lw_prepare_point_run_trajectory( ...
        trajectory, defaultDwellSeconds, defaultSettleSeconds, config)
%LW_PREPARE_POINT_RUN_TRAJECTORY Resolve canonical per-point timing values.

if isempty(trajectory) || ~isstruct(trajectory) || ~isfield(trajectory, 'x') || ...
        isempty(trajectory.x)
    error('No point trajectory is loaded.');
end

if isfield(trajectory, 'cutPlan') && istable(trajectory.cutPlan)
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

dwellUs = lw_validate_stage_schedule_duration_us( ...
    dwellSeconds .* 1e6, config, 'Point dwell_s', true);
dwellSeconds = dwellUs .* 1e-6;
trajectory.dwellSeconds = dwellSeconds;
trajectory.preWritePauseSeconds = settleSeconds;
if ~isfield(trajectory, 'meta') || ~isstruct(trajectory.meta)
    trajectory.meta = struct();
end
trajectory.meta.pointTimingSource = timingSource;

limits = lw_stage_digital_output_schedule_limits(config);
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
    'hardwareScheduleMinimumUs', limits.minimumUs, ...
    'hardwareScheduleResolutionUs', limits.resolutionUs);
end

function [trajectory, dwellSeconds, settleSeconds] = localFromWritingPlan(trajectory)
plan = trajectory.cutPlan;
if isempty(plan) || height(plan) == 0
    error('Point Mode requires at least one writing-plan row.');
end

requiredNames = {'mode', 'x', 'y', 'z', 'power', 'dwell', 'pauseSeconds'};
missingNames = setdiff(requiredNames, plan.Properties.VariableNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan is missing internal Point Mode columns: %s.', ...
        strjoin(missingNames, ', '));
end

modeValues = string(plan.mode);
badModeIndex = find(modeValues ~= "point", 1, 'first');
if ~isempty(badModeIndex)
    error('lw:PointModeMixedPlan', ...
        ['Point Mode requires every writing-plan row to use mode=point; ', ...
        'row %d uses mode=%s.'], badModeIndex, char(modeValues(badModeIndex)));
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
