function pattern = slm_generate_drill_beam_phase(ctxOrOptions, options)
%SLM_GENERATE_DRILL_BEAM_PHASE Generate a phase-only drill-beam SLM pattern.
%
% The generated phase combines common drill-beam terms:
% axicon + vortex + helical modulation + weak lens + optional carrier grating.

if nargin < 1 || isempty(ctxOrOptions)
    ctxOrOptions = struct();
end

if nargin < 2
    if isstruct(ctxOrOptions) && isfield(ctxOrOptions, 'slm')
        options = struct();
    else
        options = ctxOrOptions;
        ctxOrOptions = struct();
    end
end

inputOptions = options;
defaults = slm_default_drill_beam_options();
if isstruct(ctxOrOptions) && isfield(ctxOrOptions, 'widthPx') && isfield(ctxOrOptions, 'heightPx')
    defaults.widthPx = ctxOrOptions.widthPx;
    defaults.heightPx = ctxOrOptions.heightPx;
    if isfield(ctxOrOptions, 'config')
        defaults.wavelengthNm = ctxOrOptions.config.wavelengthNm;
        defaults.pixelPitchUm = ctxOrOptions.config.pixelPitchUm;
        defaults.phaseUnit = ctxOrOptions.config.phaseUnit;
    end
end
options = slm_apply_defaults(options, defaults);
options = localNormalizeLegacyAxiconOptions(options, inputOptions, defaults);

widthPx = double(options.widthPx);
heightPx = double(options.heightPx);
pixelPitchMm = double(options.pixelPitchUm) * 1e-3;
wavelengthMm = double(options.wavelengthNm) * 1e-6;
k = 2 * pi / wavelengthMm;
axicon = localResolveAxiconDefinition(options, wavelengthMm, pixelPitchMm);

xPx = (1:widthPx) - widthPx / 2 - double(options.centerXpx);
yPx = (1:heightPx) - heightPx / 2 + double(options.centerYpx);
[xPxGrid, yPxGrid] = meshgrid(single(xPx), single(yPx));

xMm = double(xPxGrid) * pixelPitchMm;
yMm = double(yPxGrid) * pixelPitchMm;
[theta, radiusMm] = cart2pol(xMm, yMm);
radiusPx = hypot(double(xPxGrid), double(yPxGrid));

phase = zeros(heightPx, widthPx, 'single');
components = struct();

axiconReferenceRadiusMm = (min(widthPx, heightPx) / 2) * pixelPitchMm;
components.axicon = single(double(axicon.krRadPerMm) .* ...
    (axiconReferenceRadiusMm - radiusMm));
components.vortex = single(double(options.vortexCharge) .* theta);

rho = radiusPx ./ (min(widthPx, heightPx) / 2);
radialChirp = 2 * pi * ( ...
    double(options.omegaInner) .* rho + ...
    0.5 * (double(options.omegaOuter) - double(options.omegaInner)) .* rho .^ 2);
components.helical = single(double(options.helicalGamma) .* cos( ...
    double(options.helicalOrder) .* theta - radialChirp + deg2rad(double(options.helicalOffsetDeg))));

if isfinite(options.lensFocalLengthMm) && options.lensFocalLengthMm ~= 0
    components.lens = single(k .* (radiusMm .^ 2) ./ (2 * double(options.lensFocalLengthMm)));
else
    components.lens = zeros(heightPx, widthPx, 'single');
end

if isfield(options, 'carrierPeriodPx') && ~isempty(options.carrierPeriodPx) && isfinite(options.carrierPeriodPx)
    if options.carrierPeriodPx <= 0
        error('SLM:InvalidCarrierPeriod', 'carrierPeriodPx must be positive, Inf, or empty.');
    end

    carrierDirection = lower(char(options.carrierDirection));
    switch carrierDirection
        case {'x', 'horizontal'}
            carrierCoordinate = double(xPxGrid);
        case {'y', 'vertical'}
            carrierCoordinate = double(yPxGrid);
        otherwise
            error('SLM:InvalidCarrierDirection', ...
                'carrierDirection must be "x", "y", "horizontal", or "vertical".');
    end
    components.carrier = single(2 * pi * carrierCoordinate ./ double(options.carrierPeriodPx));
else
    components.carrier = zeros(heightPx, widthPx, 'single');
end

phase = phase + components.axicon + components.vortex + components.helical + ...
    components.lens + components.carrier;

if isfinite(options.apertureRadiusPx)
    apertureMask = radiusPx <= double(options.apertureRadiusPx);
    phase(~apertureMask) = 0;
end

pattern = struct();
pattern.name = char(options.name);
pattern.phaseData = phase;
pattern.phaseUnit = double(options.phaseUnit);
pattern.options = options;
pattern.axicon = axicon;
if options.keepComponents
    pattern.components = components;
end
pattern.createdAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

function options = localNormalizeLegacyAxiconOptions(options, inputOptions, defaults)
if ~isstruct(inputOptions)
    return;
end

usesLegacyAngle = isfield(inputOptions, 'axiconAngleDeg') && ...
    ~localHasAnyField(inputOptions, {'axiconMode', 'axiconConeAngleDeg', ...
    'axiconRadialPeriodMm', 'axiconRadialPeriodPx', 'axiconRadialCycles', 'axiconIndex', ...
    'axiconPhysicalBaseAngleDeg', 'axiconBaseAngleDeg'});
if usesLegacyAngle
    options.axiconMode = 'coneAngle';
    options.axiconConeAngleDeg = double(inputOptions.axiconAngleDeg);
    options.axiconAngleDeg = double(inputOptions.axiconAngleDeg);
elseif strcmp(char(string(options.axiconMode)), 'coneAngle') && ...
        isfield(options, 'axiconAngleDeg') && isfield(options, 'axiconConeAngleDeg') && ...
        double(options.axiconConeAngleDeg) == double(defaults.axiconConeAngleDeg) && ...
        double(options.axiconAngleDeg) ~= double(defaults.axiconAngleDeg)
    options.axiconConeAngleDeg = double(options.axiconAngleDeg);
end
end

function tf = localHasAnyField(value, names)
tf = false;
for index = 1:numel(names)
    if isfield(value, names{index})
        tf = true;
        return;
    end
end
end

function axicon = localResolveAxiconDefinition(options, wavelengthMm, pixelPitchMm)
mode = char(string(options.axiconMode));
validModes = {'coneAngle', 'radialPeriodMm', 'radialPeriodPx', 'radialCycles', 'physicalEquivalent'};
if ~any(strcmp(mode, validModes))
    error('SLM:InvalidAxiconMode', ...
        'axiconMode must be coneAngle, radialPeriodMm, radialPeriodPx, radialCycles, or physicalEquivalent.');
end

backgroundIndex = double(options.backgroundIndex);
if backgroundIndex <= 0
    error('SLM:InvalidBackgroundIndex', 'backgroundIndex must be positive.');
end
kBackground = 2 * pi * backgroundIndex / wavelengthMm;
axiconReferenceRadiusMm = (min(double(options.widthPx), double(options.heightPx)) / 2) * pixelPitchMm;

switch mode
    case 'coneAngle'
        coneAngleRad = deg2rad(double(options.axiconConeAngleDeg));
        krRadPerMm = kBackground * sin(coneAngleRad);
    case 'radialPeriodMm'
        radialPeriodMm = double(options.axiconRadialPeriodMm);
        if radialPeriodMm == 0
            error('SLM:InvalidAxiconPeriod', 'axiconRadialPeriodMm must be nonzero.');
        end
        krRadPerMm = 2 * pi / radialPeriodMm;
        sinConeAngle = krRadPerMm / kBackground;
        if abs(sinConeAngle) > 1
            error('SLM:InvalidAxiconPeriod', ...
                'axiconRadialPeriodMm is too small for the current wavelength/background index.');
        end
        coneAngleRad = asin(sinConeAngle);
    case 'radialPeriodPx'
        radialPeriodPx = double(options.axiconRadialPeriodPx);
        if radialPeriodPx == 0
            error('SLM:InvalidAxiconPeriod', 'axiconRadialPeriodPx must be nonzero.');
        end
        radialPeriodMm = radialPeriodPx * pixelPitchMm;
        krRadPerMm = 2 * pi / radialPeriodMm;
        sinConeAngle = krRadPerMm / kBackground;
        if abs(sinConeAngle) > 1
            error('SLM:InvalidAxiconPeriod', ...
                'axiconRadialPeriodPx is too small for the current wavelength/background index.');
        end
        coneAngleRad = asin(sinConeAngle);
    case 'radialCycles'
        radialCycles = double(options.axiconRadialCycles);
        if ~isfinite(radialCycles)
            error('SLM:InvalidAxiconCycles', 'axiconRadialCycles must be finite.');
        end
        krRadPerMm = 2 * pi * radialCycles / axiconReferenceRadiusMm;
        sinConeAngle = krRadPerMm / kBackground;
        if abs(sinConeAngle) > 1
            error('SLM:InvalidAxiconCycles', ...
                'axiconRadialCycles is too large for the current wavelength/background index and SLM radius.');
        end
        coneAngleRad = asin(sinConeAngle);
    otherwise
        axiconIndex = double(options.axiconIndex);
        physicalBaseAngleDeg = localPhysicalBaseAngleDeg(options);
        if axiconIndex <= 0
            error('SLM:InvalidAxiconIndex', 'axiconIndex must be positive.');
        end
        physicalBaseAngleRad = deg2rad(physicalBaseAngleDeg);
        snellArgument = (axiconIndex / backgroundIndex) * sin(physicalBaseAngleRad);
        if abs(snellArgument) > 1
            error('SLM:InvalidPhysicalAxicon', ...
                'Physical-equivalent axicon is invalid because asin argument is %.12g.', snellArgument);
        end
        coneAngleRad = asin(snellArgument) - physicalBaseAngleRad;
        krRadPerMm = kBackground * sin(coneAngleRad);
end

if ~isfinite(coneAngleRad) || abs(coneAngleRad) >= pi / 2
    error('SLM:InvalidAxiconConeAngle', ...
        'Resolved axicon cone angle must be between -90 and 90 degrees.');
end
if ~isfinite(krRadPerMm) || abs(krRadPerMm) >= kBackground
    error('SLM:InvalidAxiconWavevector', ...
        'Resolved axicon radial wavevector magnitude must be smaller than the background wave number.');
end

axicon = struct();
axicon.mode = mode;
axicon.krRadPerMm = krRadPerMm;
axicon.radialPhaseSlopeRadPerMm = krRadPerMm;
axicon.coneAngleRad = coneAngleRad;
axicon.coneAngleDeg = rad2deg(coneAngleRad);
axicon.radialPeriodMm = 2 * pi / krRadPerMm;
axicon.radialPeriodPx = axicon.radialPeriodMm / pixelPitchMm;
axicon.radialCycles = krRadPerMm * axiconReferenceRadiusMm / (2 * pi);
axicon.gridPixelPitchMm = pixelPitchMm;
axicon.referenceRadiusMm = axiconReferenceRadiusMm;
axicon.backgroundIndex = backgroundIndex;
axicon.physicalIndex = double(options.axiconIndex);
axicon.physicalBaseAngleDeg = localPhysicalBaseAngleDeg(options);
axicon.physicalBaseAngleRad = deg2rad(axicon.physicalBaseAngleDeg);
end

function value = localPhysicalBaseAngleDeg(options)
if isfield(options, 'axiconPhysicalBaseAngleDeg') && ~isempty(options.axiconPhysicalBaseAngleDeg)
    value = double(options.axiconPhysicalBaseAngleDeg);
elseif isfield(options, 'axiconBaseAngleDeg') && ~isempty(options.axiconBaseAngleDeg)
    value = double(options.axiconBaseAngleDeg);
else
    value = double(options.axiconAngleDeg);
end
end
