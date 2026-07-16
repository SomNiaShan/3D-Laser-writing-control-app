function slm_set_wavelength(ctx, wavelengthNm)
%SLM_SET_WAVELENGTH Set the incident wavelength used by phase overlays.

if nargin < 2 || isempty(wavelengthNm) || wavelengthNm <= 0
    error('SLM:InvalidWavelength', 'wavelengthNm must be a positive scalar.');
end

slm = slm_get_handle(ctx);
heds_slm_set_wavelength(slm, single(wavelengthNm), true);
end
