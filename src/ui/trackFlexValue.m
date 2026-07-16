function weight = trackFlexValue(trackSize)
weight = NaN;
if isstring(trackSize) || ischar(trackSize)
    textValue = char(trackSize);
    textValue = strtrim(textValue);
    if endsWith(textValue, 'x')
        weight = str2double(textValue(1:end - 1));
        if ~isfinite(weight) || weight <= 0
            weight = 1;
        end
    end
end
end
