function innerRadiusPx = slm_lens_radius_from_focal_length(focalLengthMm, wavelengthNm, pixelPitchUm)
%SLM_LENS_RADIUS_FROM_FOCAL_LENGTH Convert Fresnel lens focal length to radius.
%
% The radius is the pixel distance where the lens phase reaches 2*pi for the
% first time. The HOLOEYE SDK uses f = (r * pixelPitch)^2 / (2 * lambda).

if nargin < 1 || isempty(focalLengthMm)
    error('SLM:MissingFocalLength', 'focalLengthMm is required.');
end

cfg = slm_config();
if nargin < 2 || isempty(wavelengthNm)
    wavelengthNm = cfg.wavelengthNm;
end
if nargin < 3 || isempty(pixelPitchUm)
    pixelPitchUm = cfg.pixelPitchUm;
end

if ~isnumeric(focalLengthMm) || ~isscalar(focalLengthMm) || focalLengthMm == 0
    error('SLM:InvalidFocalLength', 'focalLengthMm must be a nonzero numeric scalar.');
end
if ~isnumeric(wavelengthNm) || ~isscalar(wavelengthNm) || wavelengthNm <= 0
    error('SLM:InvalidWavelength', 'wavelengthNm must be a positive numeric scalar.');
end
if ~isnumeric(pixelPitchUm) || ~isscalar(pixelPitchUm) || pixelPitchUm <= 0
    error('SLM:InvalidPixelPitch', 'pixelPitchUm must be a positive numeric scalar.');
end

focalLengthM = abs(double(focalLengthMm)) * 1e-3;
wavelengthM = double(wavelengthNm) * 1e-9;
pixelPitchM = double(pixelPitchUm) * 1e-6;

innerRadiusPx = sqrt(2 * wavelengthM * focalLengthM) / pixelPitchM;
end
