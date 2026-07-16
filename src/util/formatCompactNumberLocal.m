function textValue = formatCompactNumberLocal(value)
if abs(value - round(value)) < 1e-9
    textValue = sprintf('%.0f', value);
else
    textValue = sprintf('%.3f', value);
end
end
