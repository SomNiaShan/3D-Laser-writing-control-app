function lw_set_stage_pulse_trigger(state, isActive, config)
%LW_SET_STAGE_PULSE_TRIGGER Toggle the stage digital output used as pulse trigger.

[axisHandle, channelNumber] = lw_resolve_stage_pulse_trigger(state, config);
action = lw_stage_pulse_trigger_action(isActive, config);

axisHandle.getDevice().getIO().setDigitalOutput(channelNumber, action);
end
