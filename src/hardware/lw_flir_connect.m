function flir = lw_flir_connect(flir, deviceIndex)
%LW_FLIR_CONNECT Initialize a FLIR/Teledyne Spinnaker camera by 1-based index.

if nargin < 1 || isempty(flir)
    flir = lw_flir_default_state();
end
if nargin < 2 || isempty(deviceIndex)
    deviceIndex = 1;
end
if lw_flir_is_connected(flir)
    return;
end

if ~isfield(flir, 'camList') || isempty(flir.camList)
    flir = lw_flir_refresh_devices(flir);
end

count = double(flir.camList.Count);
deviceIndex = round(double(deviceIndex));
if count < 1
    error('No Spinnaker camera detected. Check the USB cable and close SpinView.');
end
if deviceIndex < 1 || deviceIndex > count
    error('FLIR camera index %d is outside the detected camera range 1..%d.', deviceIndex, count);
end

try
    flir.cam = flir.camList.Item(deviceIndex - 1);
    flir.tlNodeMap = flir.cam.GetTLDeviceNodeMap();
    flir.cam.Init();
    flir.nodeMap = flir.cam.GetNodeMap();
    flir.isConnected = true;
    flir.isAcquiring = false;
    flir.selectedDevice = flir.devices(deviceIndex);
    lw_flir_set_enum_node(flir.nodeMap, 'AcquisitionMode', 'Continuous', false);
catch ME
    lw_flir_disconnect(flir);
    rethrow(ME);
end
end
