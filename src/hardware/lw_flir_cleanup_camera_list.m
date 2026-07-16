function flir = lw_flir_cleanup_camera_list(flir)
%LW_FLIR_CLEANUP_CAMERA_LIST Release cached Spinnaker camera-list objects.

if nargin < 1 || isempty(flir)
    flir = lw_flir_default_state();
    return;
end

if isfield(flir, 'camList') && ~isempty(flir.camList)
    try
        flir.camList.Clear();
    catch
    end
end
flir.camList = [];

if isfield(flir, 'system') && ~isempty(flir.system)
    try
        flir.system.Dispose();
    catch
    end
end
flir.system = [];
end
