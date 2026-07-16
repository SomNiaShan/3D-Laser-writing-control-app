function ctx = slm_init(config)
%SLM_INIT Initialize the HOLOEYE SDK and open the PLUTO-2.1 SLM.

if nargin < 1
    config = slm_config();
else
    config = slm_apply_defaults(config, slm_config());
end

slm_add_sdk_path(config);

load_heds_types;
global heds_types %#ok<GVMIS>

if config.printSdkVersion
    heds_sdk_print_version();
end

heds_sdk_init(config.sdkVersionMajor, config.sdkVersionMinor);

if config.closeExistingWindowsOnInit
    heds_sdk_close_all();
end

slm = heds_slm_init(config.preselect, config.openPreview, config.previewScale);

if isfield(config, 'wavelengthNm') && ~isempty(config.wavelengthNm) && config.wavelengthNm > 0
    heds_slm_set_wavelength(slm, single(config.wavelengthNm), true);
end

ctx = struct();
ctx.slm = slm;
ctx.config = config;
ctx.widthPx = double(heds_slm_width_px(slm));
ctx.heightPx = double(heds_slm_height_px(slm));
ctx.initialized = true;
ctx.sdkTypes = heds_types;

if ctx.widthPx ~= config.expectedWidthPx || ctx.heightPx ~= config.expectedHeightPx
    warning('SLM:UnexpectedResolution', ...
        'Detected SLM resolution is %d x %d px, expected %d x %d px.', ...
        ctx.widthPx, ctx.heightPx, config.expectedWidthPx, config.expectedHeightPx);
end
end
