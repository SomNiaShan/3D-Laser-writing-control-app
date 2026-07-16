function state = lw_home_stages(state)
%LW_HOME_STAGES Home all stages and refresh position.

state.devices.x.getAllAxes().home();
state.devices.y.getAllAxes().home();
state.devices.z.getAllAxes().home();
state.axes.x.waitUntilIdle();
state.axes.y.waitUntilIdle();
state.axes.z.waitUntilIdle();
state.currentPosition = lw_get_position(state);
end
