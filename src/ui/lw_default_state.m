function state = lw_default_state()
%LW_DEFAULT_STATE Create the default runtime state structure.

state = struct();

state.conn = [];
state.devices = struct('x', [], 'y', [], 'z', []);
state.axes = struct('x', [], 'y', [], 'z', []);
state.daq = [];
state.flir = lw_flir_default_state();
state.carbide = struct( ...
    'connected', false, ...
    'baseUrl', "", ...
    'lastBasic', [], ...
    'presets', [], ...
    'presetIndices', [], ...
    'statusTimer', [], ...
    'lastError', "", ...
    'pollFailureCount', 0);
state.isBusy = false;
state.stopRequested = false;
state.pauseRequested = false;
state.isPaused = false;
state.resumeContext = [];
state.laserIsOn = false;
state.currentPosition = struct('x', NaN, 'y', NaN, 'z', NaN);
state.marks = struct('mark0', [], 'mark1', [], 'mark2', []);
state.trajectory = [];
end
