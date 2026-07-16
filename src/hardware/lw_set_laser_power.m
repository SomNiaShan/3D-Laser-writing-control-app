function lw_set_laser_power(state, powerPercent)
%LW_SET_LASER_POWER Set the laser power output as a percentage.

if isempty(state.daq)
    error('DAQ is not connected.');
end

powerPercent = validatePowerPercent(powerPercent, 'Laser power');
write(state.daq, powerPercent / 10);
end
