function tooltipText = carbideOperatingStateTooltip(stateText, source)
parts = "Carbide state: " + string(stateText);

generalStatus = strtrim(carbideTextField(source, "GeneralStatus", ""));
if strlength(generalStatus) > 0
    parts(end + 1) = "General status: " + generalStatus;
end

errorsText = carbideMessagesSummary(carbideField(source, "Errors", []));
if strlength(errorsText) > 0
    parts(end + 1) = "Errors: " + errorsText;
end

warningsText = carbideMessagesSummary(carbideField(source, "Warnings", []));
if strlength(warningsText) > 0
    parts(end + 1) = "Warnings: " + warningsText;
end

tooltipText = char(strjoin(parts, newline));
end
