function stateText = carbideOperatingStateText(source)
stateText = carbideTextField(source, ...
    ["ActualStateName", "StateName", "ActualState", "SystemState", "LaserState", "GeneralStatus"], "-");
stateText = string(strtrim(char(stateText)));
if stateText == ""
    stateText = "-";
    return;
end

stateText = string(regexprep(char(stateText), '([a-z])([A-Z])', '$1 $2'));
stateText = string(regexprep(char(stateText), '[_-]+', ' '));
stateText = string(regexprep(char(stateText), '\s+', ' '));
lowerText = lower(stateText);
if contains(lowerText, "operational")
    stateText = "Operational";
elseif contains(lowerText, "housekeeping")
    stateText = "Housekeeping";
elseif contains(lowerText, "standby") || contains(lowerText, "standing by") || contains(lowerText, "stand by")
    stateText = "Standing by";
end
end
