function slm_show_lens(ctx, innerRadiusPx, centerX, centerY)
%SLM_SHOW_LENS Show a built-in Fresnel lens phase function.

if nargin < 2 || isempty(innerRadiusPx)
    if isstruct(ctx) && isfield(ctx, 'heightPx')
        innerRadiusPx = ctx.heightPx / 3;
    else
        innerRadiusPx = 120;
    end
end
if nargin < 3 || isempty(centerX)
    centerX = 0;
end
if nargin < 4 || isempty(centerY)
    centerY = 0;
end
if ~isnumeric(innerRadiusPx) || ~isscalar(innerRadiusPx) || innerRadiusPx <= 0
    error('SLM:InvalidLensRadius', 'innerRadiusPx must be a positive scalar.');
end

slm = slm_get_handle(ctx);
heds_slm_show_phasefunction_lens( ...
    slm, int32(round(innerRadiusPx)), int32(round(centerX)), int32(round(centerY)));
end
