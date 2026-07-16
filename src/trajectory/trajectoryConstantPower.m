function value = trajectoryConstantPower(trajectory, tolerance)
%TRAJECTORYCONSTANTPOWER Return the single execution power of a fixed-power plan.

if nargin < 2
    tolerance = 1e-9;
end
if isempty(trajectory) || ~isfield(trajectory, 'power') || isempty(trajectory.power)
    error('lw:MissingExecutionPower', ...
        'The loaded plan does not contain execution power values.');
end

values = validatePowerPercentValues(trajectory.power(:), 'Plan execution power');
value = values(1);
if any(abs(values - value) > tolerance)
    error('lw:VariableStreamPower', ['Stream Mode requires one constant execution power. ', ...
        'This plan contains powers from %.2f to %.2f percent; use Point Mode instead.'], ...
        min(values), max(values));
end
end
