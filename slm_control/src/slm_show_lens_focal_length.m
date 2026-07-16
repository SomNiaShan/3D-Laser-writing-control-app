function innerRadiusPx = slm_show_lens_focal_length(ctx, focalLengthMm, centerX, centerY)
%SLM_SHOW_LENS_FOCAL_LENGTH Show a Fresnel lens by focal length in mm.

if nargin < 2 || isempty(focalLengthMm)
    error('SLM:MissingFocalLength', 'focalLengthMm is required.');
end
if nargin < 3 || isempty(centerX)
    centerX = 0;
end
if nargin < 4 || isempty(centerY)
    centerY = 0;
end

if ~isstruct(ctx) || ~isfield(ctx, 'widthPx') || ~isfield(ctx, 'heightPx')
    error('SLM:InvalidContext', 'ctx must be an SLM context returned by slm_init.');
end

cfg = ctx.config;
innerRadiusPx = slm_lens_radius_from_focal_length( ...
    focalLengthMm, cfg.wavelengthNm, cfg.pixelPitchUm);

phaseUnit = single(cfg.phaseUnit);
dataWidth = double(ctx.widthPx);
dataHeight = double(ctx.heightPx);

x = (1:dataWidth) - dataWidth / 2 - double(centerX);
xSquared = single(x .* x);

y = (1:dataHeight) - dataHeight / 2 + double(centerY);
ySquared = single((y .* y)');

phaseSign = single(sign(focalLengthMm));
phaseData = phaseSign * phaseUnit * ...
    (ones(dataHeight, 1, 'single') * xSquared + ySquared * ones(1, dataWidth, 'single')) / ...
    single(innerRadiusPx * innerRadiusPx);

slm_show_phase(ctx, phaseData, cfg.phaseUnit);
end
