function textValue = formatCarbidePulseEnergyField(source)
pulseEnergyUj = carbidePulseEnergyMicroJoules(source);
if isfinite(pulseEnergyUj)
    textValue = formatCompactNumberLocal(pulseEnergyUj);
else
    textValue = '-';
end
end
