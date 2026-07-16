function slm = slm_get_handle(ctx)
%SLM_GET_HANDLE Return the HOLOEYE SDK SLM handle from a context or handle.

if isstruct(ctx) && isfield(ctx, 'slm')
    slm = ctx.slm;
else
    slm = ctx;
end
end
