function adjustedPattern = applyBatchGlobalAdjustments(pattern, globalOptions, ctx)
phaseUnit = batchPatternPhaseUnit(pattern, ctx);
phase = single(pattern.phaseData);
[heightPx, widthPx] = size(phase);
[xPxGrid, yPxGrid] = centeredPixelGrid(widthPx, heightPx);

if isfinite(globalOptions.lensFocalLengthMm) && globalOptions.lensFocalLengthMm ~= 0
    cfg = globalAdjustmentConfig(pattern, ctx);
    pixelPitchMm = double(cfg.pixelPitchUm) * 1e-3;
    wavelengthMm = double(cfg.wavelengthNm) * 1e-6;
    k = 2 * pi / wavelengthMm;
    radiusMm = hypot(double(xPxGrid), double(yPxGrid)) * pixelPitchMm;
    phase = phase + single(k .* (radiusMm .^ 2) ./ ...
        (2 * double(globalOptions.lensFocalLengthMm)));
end

if isfinite(globalOptions.xShiftTwoPi) && globalOptions.xShiftTwoPi ~= 0
    phase = phase + single(2 * pi * double(globalOptions.xShiftTwoPi) .* ...
        double(xPxGrid) ./ double(widthPx));
end

if isfinite(globalOptions.yShiftTwoPi) && globalOptions.yShiftTwoPi ~= 0
    phase = phase + single(2 * pi * double(globalOptions.yShiftTwoPi) .* ...
        double(yPxGrid) ./ double(heightPx));
end

if isfinite(globalOptions.apertureRadiusPx)
    apertureMask = hypot( ...
        double(xPxGrid) - double(globalOptions.apertureCenterXpx), ...
        double(yPxGrid) - double(globalOptions.apertureCenterYpx)) <= double(globalOptions.apertureRadiusPx);
    phase(~apertureMask) = 0;
end

adjustedPattern = pattern;
adjustedPattern.name = [patternName(pattern), ' + global'];
adjustedPattern.phaseData = phase;
adjustedPattern.phaseUnit = phaseUnit;
adjustedPattern.basePatternName = patternName(pattern);
adjustedPattern.globalAdjustments = globalOptions;
end

function [xPxGrid, yPxGrid] = centeredPixelGrid(widthPx, heightPx)
xPx = (1:double(widthPx)) - double(widthPx) / 2;
yPx = (1:double(heightPx)) - double(heightPx) / 2;
[xPxGrid, yPxGrid] = meshgrid(single(xPx), single(yPx));
end

function cfg = globalAdjustmentConfig(pattern, ctx)
cfg = slm_config();
if nargin >= 2 && isstruct(ctx) && isfield(ctx, 'config')
    cfg = ctx.config;
end
if isstruct(pattern) && isfield(pattern, 'options') && isstruct(pattern.options)
    if isfield(pattern.options, 'wavelengthNm') && ~isempty(pattern.options.wavelengthNm)
        cfg.wavelengthNm = pattern.options.wavelengthNm;
    end
    if isfield(pattern.options, 'pixelPitchUm') && ~isempty(pattern.options.pixelPitchUm)
        cfg.pixelPitchUm = pattern.options.pixelPitchUm;
    end
end
end

function name = patternName(pattern)
name = 'slm_pattern';
if isstruct(pattern) && isfield(pattern, 'name') && strlength(string(pattern.name)) > 0
    name = char(pattern.name);
end
end
