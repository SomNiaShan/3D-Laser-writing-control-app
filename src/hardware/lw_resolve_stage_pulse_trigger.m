function [axisHandle, channelNumber] = lw_resolve_stage_pulse_trigger(state, config)
%LW_RESOLVE_STAGE_PULSE_TRIGGER Resolve the configured Zaber DO endpoint.

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
if ~ismember(axisName, {'x', 'y', 'z'})
    error('Stage pulse trigger axis must be x, y, or z.');
end

if isfield(stageConfig, 'pulseTriggerChannel')
    channelNumber = stageConfig.pulseTriggerChannel;
elseif isfield(stageConfig, 'shutterChannel')
    channelNumber = stageConfig.shutterChannel;
else
    error('Stage pulse trigger channel is not configured.');
end

channelNumber = double(channelNumber);
if ~isscalar(channelNumber) || ~isfinite(channelNumber) || channelNumber < 1 || ...
        abs(channelNumber - round(channelNumber)) > 1e-9
    error('Stage pulse trigger channel must be a positive integer.');
end
channelNumber = round(channelNumber);

if ~isfield(state, 'axes') || isempty(state.axes) || ...
        ~isfield(state.axes, axisName) || isempty(state.axes.(axisName))
    error('Stage axis "%s" is not connected for pulse trigger control.', axisName);
end

axisHandle = state.axes.(axisName);
end
