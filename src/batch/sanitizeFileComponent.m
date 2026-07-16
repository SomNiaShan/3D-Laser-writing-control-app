function textValue = sanitizeFileComponent(rawValue, fallback)
textValue = char(strtrim(string(rawValue)));
if isempty(textValue)
    textValue = fallback;
end
textValue = regexprep(textValue, '[^\w\.=-]+', '_');
textValue = regexprep(textValue, '_+', '_');
textValue = regexprep(textValue, '^_+|_+$', '');
if isempty(textValue)
    textValue = fallback;
end
end
