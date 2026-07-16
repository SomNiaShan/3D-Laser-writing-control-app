function [flir, actualExposureUs] = lw_flir_set_exposure(flir, exposureUs)
%LW_FLIR_SET_EXPOSURE Set manual FLIR exposure time in microseconds.

if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end

lw_flir_set_enum_node(flir.nodeMap, 'ExposureAuto', 'Off', false);
actualExposureUs = lw_flir_set_float_node(flir.nodeMap, 'ExposureTime', exposureUs);
flir.lastExposureTimeUs = actualExposureUs;
end
