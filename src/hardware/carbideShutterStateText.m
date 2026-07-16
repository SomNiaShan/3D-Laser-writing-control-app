function shutterText = carbideShutterStateText(source)
shutterText = carbideTextField(source, ...
    ["ActualShutterState", "ShutterState", "MainShutterState", "PhysicalShutterState"], "-");
shutterText = string(strtrim(char(shutterText)));
if shutterText == ""
    shutterText = "-";
end

shutterText = normalizeCarbideShutterText(shutterText);
if shouldTreatCarbideOutputAsOpen(source, shutterText)
    shutterText = "Open";
end
end

function shutterText = normalizeCarbideShutterText(shutterText)
if shutterText == "-"
    return;
end

shutterText = string(regexprep(char(shutterText), '([a-z])([A-Z])', '$1 $2'));
shutterText = string(regexprep(char(shutterText), '[_-]+', ' '));
shutterText = string(regexprep(char(shutterText), '\s+', ' '));
lowerText = lower(shutterText);
if contains(lowerText, "opening")
    shutterText = "Opening";
elseif contains(lowerText, "closing")
    shutterText = "Closing";
elseif contains(lowerText, "open")
    shutterText = "Open";
elseif contains(lowerText, "closed") || contains(lowerText, "close") || contains(lowerText, "shut")
    shutterText = "Closed";
end
end

function tf = shouldTreatCarbideOutputAsOpen(source, shutterText)
tf = false;
if isempty(source) || ~isstruct(source)
    return;
end

outputOpen = carbideField(source, ...
    ["IsOutputEnabled", "IsMainOutputOpen", "MainOutputOpen", "IsOutputOpen", ...
     "OutputOpen", "ActualOutputOpen", "EmissionOpen"], []);
if islogical(outputOpen) && ~isempty(outputOpen)
    tf = outputOpen(1);
elseif isnumeric(outputOpen) && ~isempty(outputOpen) && isfinite(outputOpen(1))
    tf = outputOpen(1) ~= 0;
elseif ischar(outputOpen) || isstring(outputOpen)
    tf = isCarbideOutputOpenText(outputOpen);
end

if ~tf
    tf = isCarbideOutputOpenText(carbideTextField(source, ...
        ["OutputState", "MainOutputState", "ActualOutputState", "OutputStatus", "EmissionStatus"], ""));
end

if ~tf
    return;
end

lowerShutterText = lower(string(shutterText));
tf = lowerShutterText == "-" || contains(lowerShutterText, "unknown") || ...
    contains(lowerShutterText, "closed") || contains(lowerShutterText, "close") || ...
    contains(lowerShutterText, "shut");
end

function tf = isCarbideOutputOpenText(value)
outputText = lower(strtrim(string(value)));
if isempty(outputText)
    tf = false;
    return;
end

closedLike = contains(outputText, "disabled") | contains(outputText, "not enabled") | ...
    contains(outputText, "closed") | contains(outputText, "close and disable");
openLike = ismember(outputText, ["true", "on", "open", "opened", "enabled"]) | ...
    contains(outputText, "enabled and open") | contains(outputText, "output enabled") | ...
    contains(outputText, "main output is open");
tf = any(openLike & ~closedLike);
end
