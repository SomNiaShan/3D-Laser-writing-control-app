function state = lw_run_pulse_mode(state, config, trajectory, options)
%LW_RUN_PULSE_MODE Legacy compatibility wrapper. Use lw_run_stream_mode instead.

if nargin < 4 || isempty(options)
    options = struct();
end

state = lw_run_stream_mode(state, config, trajectory, options);
end
