function flir = lw_flir_refresh_devices(flir)
%LW_FLIR_REFRESH_DEVICES Refresh the visible Spinnaker camera list.

if nargin < 1 || isempty(flir)
    flir = lw_flir_default_state();
end
if lw_flir_is_connected(flir)
    error('Disconnect the FLIR camera before refreshing the camera list.');
end

flir = lw_flir_cleanup_camera_list(flir);
try
    flir = lw_flir_ensure_spinnaker_loaded(flir);
    flir.system = SpinnakerNET.ManagedSystem();
    version = flir.system.GetLibraryVersion();
    flir.sdkVersion = sprintf('%d.%d.%d.%d', ...
        version.major, version.minor, version.type, version.build);

    flir.camList = flir.system.GetCameras();
    count = double(flir.camList.Count);
    flir.devices = struct('Index', {}, 'Label', {}, 'Serial', {});

    for k = 1:count
        cam = flir.camList.Item(k - 1);
        tl = cam.GetTLDeviceNodeMap();
        vendor = lw_flir_read_node_string(tl, 'DeviceVendorName', 'Teledyne');
        model = lw_flir_read_node_string(tl, 'DeviceModelName', 'Camera');
        serial = lw_flir_read_node_string(tl, 'DeviceSerialNumber', '-');
        label = sprintf('%d: %s %s [%s]', k, vendor, model, serial);
        flir.devices(k).Index = k;
        flir.devices(k).Label = label;
        flir.devices(k).Serial = serial;
    end
catch ME
    lw_flir_cleanup_camera_list(flir);
    rethrow(ME);
end
end
