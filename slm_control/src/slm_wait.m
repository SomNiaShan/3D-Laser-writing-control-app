function slm_wait(ctx, milliseconds)
%SLM_WAIT Wait using the HOLOEYE SLM window timing helper.

if nargin < 2 || isempty(milliseconds)
    milliseconds = 1000;
end

slm = slm_get_handle(ctx);
heds_slm_wait(slm, int32(round(milliseconds)));
end
