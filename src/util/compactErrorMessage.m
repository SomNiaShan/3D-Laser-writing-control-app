function text = compactErrorMessage(errOrMessage)
if isa(errOrMessage, 'MException')
    rawText = string(errOrMessage.message);
else
    rawText = string(errOrMessage);
end

textValue = regexprep(rawText, '\s+', ' ');
if strlength(textValue) > 220
    textValue = extractBefore(textValue, 221) + "...";
end
text = char(textValue);
end
