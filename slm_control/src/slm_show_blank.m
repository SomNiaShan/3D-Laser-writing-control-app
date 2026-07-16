function slm_show_blank(ctx, grayValue)
%SLM_SHOW_BLANK Show one constant gray value over the full SLM.

if nargin < 2 || isempty(grayValue)
    if isstruct(ctx) && isfield(ctx, 'config') && isfield(ctx.config, 'blankGray')
        grayValue = ctx.config.blankGray;
    else
        grayValue = uint8(128);
    end
end

if isa(grayValue, 'uint8')
    value = grayValue;
elseif isnumeric(grayValue) && isscalar(grayValue) && grayValue >= 0 && grayValue <= 1
    value = single(grayValue);
elseif isnumeric(grayValue) && isscalar(grayValue)
    value = uint8(min(max(round(grayValue), 0), 255));
else
    error('SLM:InvalidGrayValue', 'grayValue must be a numeric scalar or uint8 value.');
end

slm = slm_get_handle(ctx);
heds_slm_show_blankscreen(slm, value);
end
