function values = numericList(rawValue, label, mustBePositive)
textValue = strtrim(string(rawValue));
if strlength(textValue) == 0
    error('%s must contain at least one number.', label);
end

tokens = regexp(char(textValue), '[,\s;]+', 'split');
tokens = tokens(~cellfun('isempty', tokens));
values = str2double(tokens);
if isempty(values) || any(~isfinite(values))
    error('%s must contain numbers separated by commas, spaces, or semicolons.', label);
end
if mustBePositive && any(values <= 0)
    error('%s must contain positive numbers.', label);
end
if ~mustBePositive && any(values < 0)
    error('%s must contain zero or positive numbers.', label);
end

values = values(:).';
end
