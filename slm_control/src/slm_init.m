function ctx = slm_init(config)
%SLM_INIT Initialize the HOLOEYE SDK and open the PLUTO-2.1 SLM.

if nargin < 1
    config = slm_config();
else
    config = slm_apply_defaults(config, slm_config());
end

sdkPath = config.sdkPath;
slmWindowId = [];
stage = 'locating the HOLOEYE SDK';
global heds_types %#ok<GVMIS>
try
    sdkPath = slm_add_sdk_path(config);

    stage = 'initializing the HOLOEYE SDK';
    load_heds_types;
    if config.printSdkVersion
        heds_sdk_print_version();
    end
    heds_sdk_init(config.sdkVersionMajor, config.sdkVersionMinor);

    if config.closeExistingWindowsOnInit
        stage = 'closing existing SDK windows';
        heds_sdk_close_all();
    end

    % Keep the window ID before configuring the device. The SDK convenience
    % initializer can throw after opening a window without returning its ID.
    stage = 'opening the SLM window';
    slmWindowId = heds_slmwindow_open(config.preselect);
    stage = 'configuring the SLM screen';
    heds_slmwindow_slmsetup_add_screen(slmWindowId);
    slms = heds_slmwindow_slmsetup_apply(slmWindowId);
    slm = slms(1);

    stage = 'setting the SLM wavelength';
    if isfield(config, 'wavelengthNm') && ~isempty(config.wavelengthNm) && config.wavelengthNm > 0
        heds_slm_set_wavelength(slm, single(config.wavelengthNm), true);
    end

    stage = 'reading the SLM resolution';
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

    % A PC-side preview failure must not discard a usable device connection.
    stage = 'opening the SDK preview';
    ctx.previewWarning = '';
    if config.openPreview
        try
            slm_open_sdk_preview(ctx, config.previewScale);
        catch err
            try
                slm_close_sdk_preview(ctx);
            catch
            end
            ctx.previewWarning = sprintf( ...
                'SLM is connected, but the SDK preview could not open: %s', err.message);
            warning('SLM:PreviewUnavailable', '%s', ctx.previewWarning);
        end
    end
catch err
    if ~isempty(slmWindowId)
        try
            heds_slmwindow_close(slmWindowId);
        catch cleanupErr
            err = addCause(err, cleanupErr);
        end
    end
    connectionError = MException('SLM:ConnectionFailed', ...
        'SLM connection failed while %s.\nSDK: %s\nDevice selection: %s\n%s', ...
        stage, sdkPath, config.preselect, err.message);
    throwAsCaller(addCause(connectionError, err));
end
end
