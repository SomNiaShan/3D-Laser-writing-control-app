function options = slm_default_drill_beam_options()
%SLM_DEFAULT_DRILL_BEAM_OPTIONS Default phase terms for drill-beam patterns.

cfg = slm_config();

options = struct();
options.name = 'drill_beam';
options.wavelengthNm = cfg.wavelengthNm;
options.pixelPitchUm = cfg.pixelPitchUm;
options.phaseUnit = cfg.phaseUnit;

options.widthPx = cfg.expectedWidthPx;
options.heightPx = cfg.expectedHeightPx;
options.centerXpx = 0;
options.centerYpx = 0;

options.backgroundIndex = 1.0;
options.axiconMode = 'coneAngle';
options.axiconConeAngleDeg = 0.4;
options.axiconIndex = 1.4287;
options.axiconPhysicalBaseAngleDeg = localEquivalentPhysicalBaseAngleDeg( ...
    deg2rad(options.axiconConeAngleDeg), options.axiconIndex, options.backgroundIndex);
options.axiconAngleDeg = options.axiconConeAngleDeg;
options = localSyncAxiconEquivalentDefaults(options);
options.vortexCharge = 1;

options.helicalGamma = 0;
options.helicalOrder = 3;
options.helicalOffsetDeg = 0;
options.omegaInner = 0;
options.omegaOuter = 0;

options.lensFocalLengthMm = Inf;

% Optional carrier grating for steering/separating orders. Set period to Inf
% or [] to disable it.
options.carrierPeriodPx = Inf;
options.carrierDirection = 'x';

options.apertureRadiusPx = Inf;
options.keepComponents = false;
end

function options = localSyncAxiconEquivalentDefaults(options)
wavelengthMm = double(options.wavelengthNm) * 1e-6;
pixelPitchMm = double(options.pixelPitchUm) * 1e-3;
referenceRadiusMm = (min(double(options.widthPx), double(options.heightPx)) / 2) * pixelPitchMm;
kBackground = 2 * pi * double(options.backgroundIndex) / wavelengthMm;
krRadPerMm = kBackground * sin(deg2rad(double(options.axiconConeAngleDeg)));
options.axiconRadialPeriodMm = localRadialPeriodFromKr(krRadPerMm);
options.axiconRadialPeriodPx = options.axiconRadialPeriodMm / pixelPitchMm;
options.axiconRadialCycles = krRadPerMm * referenceRadiusMm / (2 * pi);
end

function radialPeriodMm = localRadialPeriodFromKr(krRadPerMm)
if krRadPerMm == 0
    radialPeriodMm = Inf;
    return;
end
radialPeriodMm = 2 * pi / krRadPerMm;
end

function baseAngleDeg = localEquivalentPhysicalBaseAngleDeg(coneAngleRad, axiconIndex, backgroundIndex)
indexRatio = double(axiconIndex) / double(backgroundIndex);
denominator = indexRatio - cos(coneAngleRad);
if denominator <= 0
    baseAngleDeg = NaN;
    return;
end
baseAngleDeg = rad2deg(atan2(sin(coneAngleRad), denominator));
end
