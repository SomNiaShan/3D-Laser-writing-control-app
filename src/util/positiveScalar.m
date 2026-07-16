function value = positiveScalar(rawValue, label)
value = double(rawValue);
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error('%s must be a positive number.', label);
end
end
