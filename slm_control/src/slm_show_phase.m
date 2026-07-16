function slm_show_phase(ctx, phaseData, phaseUnit, flags)
%SLM_SHOW_PHASE Show a numeric phase matrix on the SLM.

if nargin < 2 || isempty(phaseData)
    error('SLM:MissingPhaseData', 'phaseData is required.');
end
if ~isnumeric(phaseData) || ~ismatrix(phaseData)
    error('SLM:InvalidPhaseData', 'phaseData must be a 2-D numeric matrix.');
end

if nargin < 3 || isempty(phaseUnit)
    if isstruct(ctx) && isfield(ctx, 'config') && isfield(ctx.config, 'phaseUnit')
        phaseUnit = ctx.config.phaseUnit;
    else
        phaseUnit = 2*pi;
    end
end

if nargin < 4 || isempty(flags)
    flags = uint32(0);
end

if isstruct(ctx) && isfield(ctx, 'widthPx') && isfield(ctx, 'heightPx')
    [rows, cols] = size(phaseData);
    if rows ~= ctx.heightPx || cols ~= ctx.widthPx
        warning('SLM:PhaseSizeMismatch', ...
            'phaseData is %d x %d, while the SLM is %d x %d. SDK presentation flags will decide how it is shown.', ...
            rows, cols, ctx.heightPx, ctx.widthPx);
    end
end

slm = slm_get_handle(ctx);
heds_slm_show_phasedata(slm, single(phaseData), uint32(flags), single(phaseUnit));
end
