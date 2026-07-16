function slm_close_sdk_preview(ctx)
%SLM_CLOSE_SDK_PREVIEW Close the HOLOEYE SDK SLM Preview window.

slm = slm_get_handle(ctx);
heds_slmpreview_close(slm.slmwindow_id);
end
