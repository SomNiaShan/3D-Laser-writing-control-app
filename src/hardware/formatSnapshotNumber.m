function textValue = formatSnapshotNumber(value)
if isfinite(value)
    textValue = formatCompactNumberLocal(value);
else
    textValue = '-';
end
end
