function textValue = formatCarbideOutputEnabled(source)
rawValue = carbideField(source, "IsOutputEnabled", []);
if islogical(rawValue) && ~isempty(rawValue)
    textValue = onOff(rawValue(1));
elseif isnumeric(rawValue) && ~isempty(rawValue) && isfinite(rawValue(1))
    textValue = onOff(rawValue(1) ~= 0);
elseif ischar(rawValue) || isstring(rawValue)
    textValue = char(string(rawValue));
else
    textValue = '-';
end
end
