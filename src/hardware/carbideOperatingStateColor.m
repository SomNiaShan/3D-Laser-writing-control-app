function stateColor = carbideOperatingStateColor(stateText, source)
lowerText = lower(string(stateText));
if hasCarbideMessages(carbideField(source, "Errors", [])) || any(contains(lowerText, ["error", "fault", "alarm"]))
    stateColor = [0.85, 0.2, 0.2];
elseif contains(lowerText, "operational")
    stateColor = [0.2, 0.7, 0.2];
elseif contains(lowerText, "housekeeping") || any(contains(lowerText, ["starting", "initializing", "warm"]))
    stateColor = [0.25, 0.55, 0.95];
elseif contains(lowerText, "standby") || contains(lowerText, "standing by") || contains(lowerText, "stand by")
    stateColor = [0.85, 0.2, 0.2];
elseif any(contains(lowerText, ["idle", "wait"]))
    stateColor = [0.95, 0.7, 0.15];
elseif contains(lowerText, "warn")
    stateColor = [0.95, 0.55, 0.1];
else
    stateColor = [0.5, 0.5, 0.5];
end
end
