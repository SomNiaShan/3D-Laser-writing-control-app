function value = positiveInteger(rawValue, label)
value = round(double(rawValue));
if ~isscalar(value) || ~isfinite(value) || value < 1
    error('%s must be a positive integer.', label);
end
end
