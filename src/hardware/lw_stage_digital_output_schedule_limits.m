function limits = lw_stage_digital_output_schedule_limits(config)
%LW_STAGE_DIGITAL_OUTPUT_SCHEDULE_LIMITS Read validated Zaber DO timing limits.

if nargin < 1 || ~isstruct(config) || ~isfield(config, 'stage') || ...
        ~isstruct(config.stage)
    error('lw:stage:MissingScheduleConfiguration', ...
        'Stage digital-output schedule configuration is missing.');
end

requiredNames = {'digitalOutputScheduleMinUs', 'digitalOutputScheduleResolutionUs'};
missingNames = setdiff(requiredNames, fieldnames(config.stage), 'stable');
if ~isempty(missingNames)
    error('lw:stage:MissingScheduleConfiguration', ...
        'Stage schedule configuration is missing: %s.', strjoin(missingNames, ', '));
end

minimumUs = localPositiveFiniteScalar( ...
    config.stage.digitalOutputScheduleMinUs, 'digitalOutputScheduleMinUs');
resolutionUs = localPositiveFiniteScalar( ...
    config.stage.digitalOutputScheduleResolutionUs, 'digitalOutputScheduleResolutionUs');

limits = struct('minimumUs', minimumUs, 'resolutionUs', resolutionUs);
end

function value = localPositiveFiniteScalar(value, fieldName)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('lw:stage:InvalidScheduleConfiguration', ...
        'config.stage.%s must be a positive finite scalar.', fieldName);
end
value = double(value);
end
