function value = validatePowerPercent(rawValue, label)
%VALIDATEPOWERPERCENT Validate one scalar laser power percentage.

if nargin < 2
    label = 'Power';
end

value = validatePowerPercentValues(rawValue, label);
if ~isscalar(value)
    error('lw:InvalidPowerPercent', ...
        '%s must be a scalar from 0 to 100 percent.', label);
end
end
