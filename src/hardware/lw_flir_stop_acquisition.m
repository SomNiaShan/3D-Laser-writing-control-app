function flir = lw_flir_stop_acquisition(flir)
%LW_FLIR_STOP_ACQUISITION End FLIR acquisition if it is active.

if nargin < 1 || isempty(flir)
    flir = lw_flir_default_state();
    return;
end
if ~isfield(flir, 'isAcquiring') || ~logical(flir.isAcquiring)
    flir.isAcquiring = false;
    return;
end
if ~isfield(flir, 'cam') || isempty(flir.cam)
    flir.isAcquiring = false;
    return;
end

try
    flir.cam.EndAcquisition();
catch
end
flir.isAcquiring = false;
end
