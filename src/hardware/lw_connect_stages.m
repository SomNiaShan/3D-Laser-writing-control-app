function state = lw_connect_stages(state, config)
%LW_CONNECT_STAGES Connect to the Zaber stages and cache axis handles.

import zaber.motion.ascii.*;

state.conn = Connection.openSerialPort(config.stage.comPort);
devices = state.conn.detectDevices();

state.devices.x = devices(config.stage.deviceOrder.x);
state.devices.y = devices(config.stage.deviceOrder.y);
state.devices.z = devices(config.stage.deviceOrder.z);

state.axes.x = state.devices.x.getAxis(config.stage.axisMap.x);
state.axes.y = state.devices.y.getAxis(config.stage.axisMap.y);
state.axes.z = state.devices.z.getAxis(config.stage.axisMap.z);

try
    state.currentPosition = lw_get_position(state);
catch
end
end
