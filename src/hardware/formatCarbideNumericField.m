function textValue = formatCarbideNumericField(source, fieldNames)
value = carbideNumericField(source, fieldNames);
if isfinite(value)
    textValue = formatCompactNumberLocal(value);
else
    textValue = '-';
end
end
