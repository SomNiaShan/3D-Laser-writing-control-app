function value = batchPatternPhaseUnit(pattern, ctx)
value = 2 * pi;
if isstruct(pattern) && isfield(pattern, 'phaseUnit') && ~isempty(pattern.phaseUnit)
    value = double(pattern.phaseUnit);
elseif isstruct(ctx) && isfield(ctx, 'config') && isfield(ctx.config, 'phaseUnit')
    value = double(ctx.config.phaseUnit);
end
end
