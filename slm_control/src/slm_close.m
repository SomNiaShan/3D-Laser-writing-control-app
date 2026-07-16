function slm_close(ctx)
%SLM_CLOSE Close an SLM context or all HOLOEYE SDK windows.

if nargin >= 1 && ~isempty(ctx)
    try
        slm = slm_get_handle(ctx);
        if isstruct(slm) && isfield(slm, 'slmwindow_id')
            heds_slmwindow_close(slm.slmwindow_id);
            return;
        end
    catch err
        warning('SLM:CloseWindowFailed', ...
            'Could not close the specific SLM window: %s', err.message);
    end
end

try
    heds_close();
catch
    try
        heds_sdk_close_all();
    catch
    end
end
end
