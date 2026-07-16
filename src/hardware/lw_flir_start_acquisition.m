function flir = lw_flir_start_acquisition(flir)
%LW_FLIR_START_ACQUISITION Begin continuous FLIR acquisition.

if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end
if isfield(flir, 'isAcquiring') && logical(flir.isAcquiring)
    return;
end

flir = lw_flir_configure_stream_for_low_latency(flir);
lw_flir_set_enum_node(flir.nodeMap, 'AcquisitionMode', 'Continuous', false);
flir.cam.BeginAcquisition();
flir.isAcquiring = true;
end
