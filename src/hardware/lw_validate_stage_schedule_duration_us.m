function valuesUs = lw_validate_stage_schedule_duration_us(valuesUs, config, label, allowZero)
%LW_VALIDATE_STAGE_SCHEDULE_DURATION_US Validate hardware-representable DO times.

if nargin < 3 || strlength(string(label)) == 0
    label = 'Digital output duration';
end
if nargin < 4
    allowZero = false;
end

if ~isnumeric(valuesUs) || isempty(valuesUs) || any(~isfinite(valuesUs(:)))
    error('lw:stage:InvalidPulseWidth', '%s must contain only finite numeric values.', label);
end
if ~isscalar(allowZero) || (~islogical(allowZero) && ~isnumeric(allowZero)) || ...
        (isnumeric(allowZero) && (~isfinite(allowZero) || ~ismember(allowZero, [0, 1])))
    error('lw:stage:InvalidPulseWidth', 'allowZero must be a logical scalar.');
end
allowZero = logical(allowZero);
valuesUs = double(valuesUs);

if allowZero
    invalidSign = valuesUs < 0;
    signRequirement = 'nonnegative';
else
    invalidSign = valuesUs <= 0;
    signRequirement = 'positive';
end
if any(invalidSign(:))
    error('lw:stage:InvalidPulseWidth', '%s values must be %s.', label, signRequirement);
end

limits = lw_stage_digital_output_schedule_limits(config);
positiveMask = valuesUs > 0;
belowMinimum = positiveMask & valuesUs < limits.minimumUs;
if any(belowMinimum(:))
    index = find(belowMinimum, 1, 'first');
    error('lw:stage:PulseWidthBelowMinimum', ...
        ['%s at %s is %.9g us; this Zaber output requires 0 or at least %.9g us. ', ...
        'Increase dwell_s or the configured gate width.'], ...
        label, localIndexText(valuesUs, index), valuesUs(index), limits.minimumUs);
end

stepValues = valuesUs ./ limits.resolutionUs;
stepTolerance = 1e-9 .* max(1, abs(stepValues));
offGrid = positiveMask & abs(stepValues - round(stepValues)) > stepTolerance;
if any(offGrid(:))
    index = find(offGrid, 1, 'first');
    error('lw:stage:PulseWidthResolution', ...
        ['%s at %s is %.9g us; this Zaber output only represents multiples of %.9g us. ', ...
        'Change the requested duration instead of relying on implicit rounding.'], ...
        label, localIndexText(valuesUs, index), valuesUs(index), limits.resolutionUs);
end

valuesUs(positiveMask) = round(stepValues(positiveMask)) .* limits.resolutionUs;
end

function textValue = localIndexText(values, index)
if isscalar(values)
    textValue = 'the requested value';
else
    textValue = sprintf('row %d', index);
end
end
