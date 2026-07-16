function validateCarbideBasicResponse(basic)
requiredGroups = { ...
    ["ActualOutputPower", "OutputPower", "ActualPower"], ...
    ["ActualPpDivider", "ActualPPDivider", "PpDivider"], ...
    ["ActualOutputFrequency", "ActualFrequency", "OutputFrequency"], ...
    ["ActualPulseDuration", "PulseDuration"]};
groupNames = ["power", "PP divider", "frequency", "pulse duration"];
missingGroups = strings(1, 0);
for groupIndex = 1:numel(requiredGroups)
    if ~hasCarbideField(basic, requiredGroups{groupIndex})
        missingGroups(end + 1) = groupNames(groupIndex); %#ok<AGROW>
    end
end
if ~isempty(missingGroups)
    error('Carbide Basic response is missing expected %s fields.', ...
        char(strjoin(missingGroups, ', ')));
end
end
