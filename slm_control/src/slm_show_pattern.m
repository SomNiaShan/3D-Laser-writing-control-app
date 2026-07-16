function slm_show_pattern(ctx, pattern)
%SLM_SHOW_PATTERN Show a pattern struct or a saved pattern name on the SLM.

if nargin < 2 || isempty(pattern)
    error('SLM:MissingPattern', 'A pattern struct or saved pattern name is required.');
end

if ischar(pattern) || isstring(pattern)
    pattern = slm_load_pattern(pattern, ctx.config);
end

if ~isstruct(pattern) || ~isfield(pattern, 'phaseData')
    error('SLM:InvalidPattern', 'pattern must be a struct containing phaseData.');
end

phaseUnit = 2*pi;
if isfield(pattern, 'phaseUnit') && ~isempty(pattern.phaseUnit)
    phaseUnit = pattern.phaseUnit;
elseif isstruct(ctx) && isfield(ctx, 'config') && isfield(ctx.config, 'phaseUnit')
    phaseUnit = ctx.config.phaseUnit;
end

slm_show_phase(ctx, pattern.phaseData, phaseUnit);
end
