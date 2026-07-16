function flir = lw_flir_configure_stream_for_low_latency(flir)
%LW_FLIR_CONFIGURE_STREAM_FOR_LOW_LATENCY Prefer newest frames with a short buffer queue.

if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end

try
    streamMap = flir.cam.GetTLStreamNodeMap();
    lw_flir_set_enum_node(streamMap, 'StreamBufferCountMode', 'Manual', false);
    lw_flir_set_integer_node(streamMap, 'StreamBufferCountManual', 3, false);
    lw_flir_set_enum_node(streamMap, 'StreamBufferHandlingMode', 'NewestOnly', false);
catch
end
end
