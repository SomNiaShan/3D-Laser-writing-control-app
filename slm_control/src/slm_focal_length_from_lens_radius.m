function focalLengthMm = slm_focal_length_from_lens_radius(innerRadiusPx, wavelengthNm, pixelPitchUm)
%SLM_FOCAL_LENGTH_FROM_LENS_RADIUS Convert Fresnel lens radius to focal length.

if nargin < 1 || isempty(innerRadiusPx)
    error('SLM:MissingLensRadius', 'innerRadiusPx is required.');
end

cfg = slm_config();
if nargin < 2 || isempty(wavelengthNm)
    wavelengthNm = cfg.wavelengthNm;
end
if nargin < 3 || isempty(pixelPitchUm)
    pixelPitchUm = cfg.pixelPitchUm;
end

if ~isnumeric(innerRadiusPx) || ~isscalar(innerRadiusPx) || innerRadiusPx <= 0
    error('SLM:InvalidLensRadius', 'innerRadiusPx must be a positive numeric scalar.');
end
if ~isnumeric(wavelengthNm) || ~isscalar(wavelengthNm) || wavelengthNm <= 0
    error('SLM:InvalidWavelength', 'wavelengthNm must be a positive numeric scalar.');
end
if ~isnumeric(pixelPitchUm) || ~isscalar(pixelPitchUm) || pixelPitchUm <= 0
    error('SLM:InvalidPixelPitch', 'pixelPitchUm must be a positive numeric scalar.');
end

radiusM = double(innerRadiusPx) * double(pixelPitchUm) * 1e-6;
wavelengthM = double(wavelengthNm) * 1e-9;

focalLengthMm = (radiusM * radiusM) / (2 * wavelengthM) * 1e3;
end
