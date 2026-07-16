function lw_validate_target_for_ui(target, limits, yDisplayReference, actionLabel)
%LW_VALIDATE_TARGET_FOR_UI Validate an XYZ target against configured limits.

validateAxisTarget('X', target.x, limits.x, actionLabel);
validateAxisTarget('Z', target.z, limits.z, actionLabel);

yDisplayRange = sort(yDisplayReference - limits.y);
yDisplayValue = yDisplayReference - target.y;
validateAxisTarget('Y', yDisplayValue, yDisplayRange, actionLabel);
end

function validateAxisTarget(axisLabel, value, limitsRange, actionLabel)
if ~isscalar(value) || ~isfinite(value)
    error('%s cancelled: %s target is not finite.', actionLabel, axisLabel);
end
if value < limitsRange(1) || value > limitsRange(2)
    error('%s cancelled: %s target %.3f mm is outside [%.3f, %.3f] mm.', ...
        actionLabel, axisLabel, value, limitsRange(1), limitsRange(2));
end
end
