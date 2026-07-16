function values = zSweepMatrixDirectionList(rawValue)
textValue = strtrim(string(rawValue));
if strlength(textValue) == 0
    error('Z Sweep matrix exposure direction values must contain at least one direction.');
end

tokens = regexp(char(textValue), '\s*[,;]\s*', 'split');
tokens = tokens(~cellfun('isempty', tokens));
values = strings(1, numel(tokens));
for tokenIndex = 1:numel(tokens)
    normalizedToken = lower(strtrim(string(tokens{tokenIndex})));
    normalizedToken = regexprep(normalizedToken, '\s+', ' ');
    switch normalizedToken
        case {"back -> front", "back->front", "back front", "bf"}
            values(tokenIndex) = "Back -> Front";
        case {"front -> back", "front->back", "front back", "fb"}
            values(tokenIndex) = "Front -> Back";
        case {"both directions", "both", "bd"}
            values(tokenIndex) = "Both Directions";
        otherwise
            error(['Unsupported Z Sweep matrix exposure direction "%s". ', ...
                'Use Back -> Front, Front -> Back, Both Directions, BF, FB, or Both.'], ...
                tokens{tokenIndex});
    end
end
end
