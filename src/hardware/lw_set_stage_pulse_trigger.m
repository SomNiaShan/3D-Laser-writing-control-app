function lw_set_stage_pulse_trigger(state, isActive, config)
%LW_SET_STAGE_PULSE_TRIGGER Toggle the stage digital output used as pulse trigger.

import zaber.motion.ascii.DigitalOutputAction;

[axisHandle, channelNumber] = resolvePulseTriggerHandle(state, config);

if isActive
    action = DigitalOutputAction.ON;
else
    action = DigitalOutputAction.OFF;
end

axisHandle.getDevice().getIO().setDigitalOutput(channelNumber, action);
end

function [axisHandle, channelNumber] = resolvePulseTriggerHandle(state, config)
if nargin < 2 || isempty(config) || ~isfield(config, 'stage') || isempty(config.stage)
    error('Pulse trigger configuration is missing.');
end

stageConfig = config.stage;
if isfield(stageConfig, 'pulseTriggerAxis')
    axisName = lower(char(stageConfig.pulseTriggerAxis));
elseif isfield(stageConfig, 'shutterAxis')
    axisName = lower(char(stageConfig.shutterAxis));
else
    error('Stage pulse trigger axis is not configured.');
end

if isfield(stageConfig, 'pulseTriggerChannel')
    channelNumber = stageConfig.pulseTriggerChannel;
elseif isfield(stageConfig, 'shutterChannel')
    channelNumber = stageConfig.shutterChannel;
else
    error('Stage pulse trigger channel is not configured.');
end

channelNumber = double(channelNumber);
if ~isscalar(channelNumber) || ~isfinite(channelNumber) || channelNumber < 1
    error('Stage pulse trigger channel must be a positive integer.');
end

if ~isfield(state, 'axes') || isempty(state.axes) || ~isfield(state.axes, axisName) || isempty(state.axes.(axisName))
    error('Stage axis "%s" is not connected for pulse trigger control.', axisName);
end

axisHandle = state.axes.(axisName);
end
