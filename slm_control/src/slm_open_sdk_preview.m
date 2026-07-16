function slm_open_sdk_preview(ctx, previewScale)
%SLM_OPEN_SDK_PREVIEW Open the HOLOEYE SDK SLM Preview window.

if nargin < 2 || isempty(previewScale)
    previewScale = 0;
end

slm = slm_get_handle(ctx);
heds_slmpreview_open(slm.slmwindow_id);

if isstruct(ctx) && isfield(ctx, 'sdkTypes')
    heds_slmpreview_set_settings(slm.slmwindow_id, ctx.sdkTypes.HEDSSLMPF_None, previewScale);
end
end
