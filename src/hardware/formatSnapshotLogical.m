function textValue = formatSnapshotLogical(value)
if islogical(value) && ~isempty(value)
    textValue = onOff(value(1));
elseif isnumeric(value) && ~isempty(value) && isfinite(value(1))
    textValue = onOff(value(1) ~= 0);
elseif ischar(value) || isstring(value)
    textValue = char(string(value));
else
    textValue = '-';
end
end
