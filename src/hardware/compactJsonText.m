function textValue = compactJsonText(value)
try
    textValue = string(jsonencode(value));
catch
    textValue = string(value);
end
textValue = regexprep(textValue, '\s+', ' ');
if strlength(textValue) > 700
    textValue = extractBefore(textValue, 701) + "...";
end
textValue = char(textValue);
end
