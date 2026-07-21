function action = lw_stage_pulse_trigger_action(isActive, config)
%LW_STAGE_PULSE_TRIGGER_ACTION Map logical laser state through configured polarity.

if ~isscalar(isActive) || (~islogical(isActive) && ~isnumeric(isActive)) || ...
        (isnumeric(isActive) && (~isfinite(isActive) || ~ismember(isActive, [0, 1])))
    error('lw:stage:InvalidPulseTriggerState', ...
        'Pulse trigger state must be a logical scalar.');
end
if nargin < 2 || ~isstruct(config) || ~isfield(config, 'stage') || ...
        ~isstruct(config.stage) || ~isfield(config.stage, 'pulseTriggerActiveHigh')
    error('lw:stage:MissingPulseTriggerPolarity', ...
        ['Pulse trigger polarity is not configured. Set ', ...
        'config.stage.pulseTriggerActiveHigh explicitly.']);
end

activeHigh = config.stage.pulseTriggerActiveHigh;
if ~isscalar(activeHigh) || (~islogical(activeHigh) && ~isnumeric(activeHigh)) || ...
        (isnumeric(activeHigh) && (~isfinite(activeHigh) || ~ismember(activeHigh, [0, 1])))
    error('lw:stage:InvalidPulseTriggerPolarity', ...
        'config.stage.pulseTriggerActiveHigh must be a logical scalar.');
end

outputIsHigh = logical(isActive) == logical(activeHigh);
if outputIsHigh
    action = zaber.motion.ascii.DigitalOutputAction.ON;
else
    action = zaber.motion.ascii.DigitalOutputAction.OFF;
end
end
