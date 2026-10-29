function durationSeconds = lw_schedule_stage_pulse_trigger(state, durationSeconds, config)
%LW_SCHEDULE_STAGE_PULSE_TRIGGER Start a firmware-timed Zaber DO gate.

if ~isnumeric(durationSeconds) || ~isscalar(durationSeconds) || ...
        ~isfinite(durationSeconds)
    error('lw:stage:InvalidPulseWidth', ...
        'Scheduled exposure duration must be a finite numeric scalar.');
end

durationUs = lw_validate_stage_schedule_duration_us( ...
    double(durationSeconds) .* 1e6, config, 'Scheduled exposure duration', false);
durationSeconds = durationUs .* 1e-6;

[axisHandle, channelNumber] = lw_resolve_stage_pulse_trigger(state, config);
activeAction = lw_stage_pulse_trigger_action(true, config);
inactiveAction = lw_stage_pulse_trigger_action(false, config);
axisHandle.getDevice().getIO().setDigitalOutputSchedule( ...
    channelNumber, activeAction, inactiveAction, durationUs, ...
    zaber.motion.Units.TIME_MICROSECONDS);
end
