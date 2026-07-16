function value = nonnegativeScalar(rawValue, label)
value = double(rawValue);
if ~isscalar(value) || ~isfinite(value) || value < 0
    error('%s must be zero or positive.', label);
end
end
