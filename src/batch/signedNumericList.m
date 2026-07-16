function values = signedNumericList(rawValue, label)
textValue = strtrim(string(rawValue));
if strlength(textValue) == 0
    error('%s must contain at least one number.', label);
end
tokens = regexp(char(textValue), '[,\s;]+', 'split');
tokens = tokens(~cellfun('isempty', tokens));
values = str2double(tokens);
if isempty(values) || any(isnan(values))
    error('%s must contain numbers separated by commas, spaces, or semicolons.', label);
end
values = values(:).';
end
