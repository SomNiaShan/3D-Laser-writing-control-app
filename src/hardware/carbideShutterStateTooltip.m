function tooltipText = carbideShutterStateTooltip(shutterText, source)
tooltipParts = "Carbide physical shutter: " + string(shutterText);
rawShutterText = strtrim(carbideTextField(source, ...
    ["ActualShutterState", "ShutterState", "MainShutterState", "PhysicalShutterState"], ""));
if ~isempty(rawShutterText)
    rawShutterText = rawShutterText(1);
end
if strlength(rawShutterText) > 0 && ~strcmpi(char(rawShutterText), char(string(shutterText)))
    tooltipParts(end + 1) = "Raw shutter state: " + rawShutterText;
end
outputText = formatCarbideOutputEnabled(source);
if ~strcmp(char(outputText), '-')
    tooltipParts(end + 1) = "Output enabled: " + string(outputText);
end
tooltipText = char(strjoin(tooltipParts, newline));
end
