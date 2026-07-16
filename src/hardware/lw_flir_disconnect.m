function flir = lw_flir_disconnect(flir)
%LW_FLIR_DISCONNECT Best-effort FLIR camera cleanup.

if nargin < 1 || isempty(flir)
    flir = lw_flir_default_state();
    return;
end

try
    flir = lw_flir_stop_acquisition(flir);
catch
    if isfield(flir, 'isAcquiring')
        flir.isAcquiring = false;
    end
end

if isfield(flir, 'cam') && ~isempty(flir.cam)
    try
        if flir.cam.IsInitialized
            flir.cam.DeInit();
        end
    catch
    end
    try
        flir.cam.Dispose();
    catch
    end
end

sdkLoaded = isfield(flir, 'sdkLoaded') && logical(flir.sdkLoaded);
sdkPath = '';
sdkVersion = '';
if isfield(flir, 'sdkPath')
    sdkPath = flir.sdkPath;
end
if isfield(flir, 'sdkVersion')
    sdkVersion = flir.sdkVersion;
end

flir = lw_flir_cleanup_camera_list(flir);
flir.cam = [];
flir.nodeMap = [];
flir.tlNodeMap = [];
flir.selectedDevice = [];
flir.lastFrame = [];
flir.lastFrameInfo = struct();
flir.currentRoi = struct();
flir.isConnected = false;
flir.isAcquiring = false;
flir.isGrabbing = false;
flir.sdkLoaded = sdkLoaded;
flir.sdkPath = sdkPath;
flir.sdkVersion = sdkVersion;
flir.lastExposureTimeUs = NaN;
flir.lastGain = NaN;
end
