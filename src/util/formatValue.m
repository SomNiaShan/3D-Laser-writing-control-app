function value = formatValue(numberValue)
if isfinite(numberValue)
    value = sprintf('%.3f', numberValue);
else
    value = '-';
end
end
