function position = lw_get_position(state)
%LW_GET_POSITION Read the current XYZ position in millimetres.

import zaber.motion.*;

position = struct();
position.x = state.axes.x.getPosition(Units.LENGTH_MILLIMETRES);
position.y = state.axes.y.getPosition(Units.LENGTH_MILLIMETRES);
position.z = state.axes.z.getPosition(Units.LENGTH_MILLIMETRES);
end
