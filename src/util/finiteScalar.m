function value = finiteScalar(rawValue, label)
value = double(rawValue);
if ~isscalar(value) || ~isfinite(value)
    error('%s must be a finite number.', label);
end
end
