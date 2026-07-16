function slm_show_grating(ctx, periodPx, direction)
%SLM_SHOW_GRATING Show a built-in blazed grating.

if nargin < 2 || isempty(periodPx)
    periodPx = 50;
end
if nargin < 3 || isempty(direction)
    direction = 'vertical';
end
if ~isnumeric(periodPx) || ~isscalar(periodPx) || periodPx <= 0
    error('SLM:InvalidGratingPeriod', 'periodPx must be a positive scalar.');
end

slm = slm_get_handle(ctx);
direction = lower(char(direction));

switch direction
    case {'horizontal', 'h', 'x'}
        heds_slm_show_grating_blaze_horizontal(slm, int32(round(periodPx)));
    case {'vertical', 'v', 'y'}
        heds_slm_show_grating_blaze_vertical(slm, int32(round(periodPx)));
    otherwise
        error('SLM:InvalidGratingDirection', ...
            'direction must be "horizontal" or "vertical".');
end
end
