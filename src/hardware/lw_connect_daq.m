function state = lw_connect_daq(state, config)
%LW_CONNECT_DAQ Create and configure the DAQ object.

state.daq = daq(config.daq.vendor);
addoutput(state.daq, config.daq.device, config.daq.powerChannel, "Voltage");
state.daq.Rate = config.daq.rate;
write(state.daq, 0);
end
