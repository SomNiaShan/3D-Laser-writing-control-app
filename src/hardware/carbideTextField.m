function value = carbideTextField(source, fieldNames, defaultValue)
value = string(defaultValue);
rawValue = carbideField(source, fieldNames, []);
if isempty(rawValue)
    return;
end
if iscell(rawValue)
    value = string(rawValue{1});
else
    value = string(rawValue);
end
end
