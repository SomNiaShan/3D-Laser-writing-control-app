function factor = lw_validate_auto_exposure_safety_factor(rawValue, label)
%LW_VALIDATE_AUTO_EXPOSURE_SAFETY_FACTOR Validate the scout exposure multiplier.
%   Any positive factor is accepted. 1 puts the brightest sampled pixel at
%   full scale; above 1 the brightest sampled pixels are expected to saturate.

factor = double(rawValue);
if ~isscalar(factor) || ~isfinite(factor) || factor <= 0
    error('%s auto exposure safety factor must be a positive number.', label);
end
end
