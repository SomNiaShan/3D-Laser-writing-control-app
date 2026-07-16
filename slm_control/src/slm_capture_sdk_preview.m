function filePath = slm_capture_sdk_preview(ctx, filePath, captureMode)
%SLM_CAPTURE_SDK_PREVIEW Save the HOLOEYE SDK Preview image to a file.

if nargin < 2 || isempty(filePath)
    filePath = fullfile(tempdir, 'slm_sdk_preview.png');
end

if nargin < 3 || isempty(captureMode)
    if isstruct(ctx) && isfield(ctx, 'sdkTypes')
        captureMode = ctx.sdkTypes.HEDSSLMPM_CaptureInternalFramebuffer;
    else
        captureMode = uint32(0);
    end
end

slm = slm_get_handle(ctx);
heds_slmpreview_save_to_file(slm.slmwindow_id, filePath, uint32(captureMode), true);
end
