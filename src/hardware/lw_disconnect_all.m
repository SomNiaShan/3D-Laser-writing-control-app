function state = lw_disconnect_all(state, config)
%LW_DISCONNECT_ALL Best-effort cleanup for laser, DAQ, and stages.

if nargin < 2
    config = [];
end

try
    if ~isempty(state.axes) && isfield(state.axes, 'x') && ~isempty(state.axes.x)
        lw_set_stage_pulse_trigger(state, false, config);
    end
catch
end

try
    if ~isempty(state.daq)
        write(state.daq, 0);
    end
catch
end

try
    if isfield(state, 'carbide') && isstruct(state.carbide) && ...
            isfield(state.carbide, 'statusTimer') && ~isempty(state.carbide.statusTimer) && ...
            isvalid(state.carbide.statusTimer)
        stop(state.carbide.statusTimer);
        delete(state.carbide.statusTimer);
    end
catch
end

try
    if isfield(state, 'flir') && isstruct(state.flir)
        state.flir = lw_flir_disconnect(state.flir);
    end
catch
end

try
    if ~isempty(state.conn)
        state.conn.close();
    end
catch
end

state = lw_default_state();
end
