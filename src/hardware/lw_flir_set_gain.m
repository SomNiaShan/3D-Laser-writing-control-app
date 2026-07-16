function [flir, actualGain] = lw_flir_set_gain(flir, gain)
%LW_FLIR_SET_GAIN Set manual FLIR gain.

if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end

lw_flir_set_enum_node(flir.nodeMap, 'GainAuto', 'Off', false);
actualGain = lw_flir_set_float_node(flir.nodeMap, 'Gain', gain);
flir.lastGain = actualGain;
end
