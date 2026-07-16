function values = validatePowerPercentValues(rawValues, label)
%VALIDATEPOWERPERCENTVALUES Validate one or more laser power percentages.

if nargin < 2 || strlength(string(label)) == 0
    label = 'Power';
end

values = double(rawValues);
if isempty(values) || any(~isfinite(values(:))) || any(values(:) < 0 | values(:) > 100)
    error('lw:InvalidPowerPercent', ...
        '%s must contain finite values from 0 to 100 percent.', label);
end
end
