function values = numericVectorFromValue(rawValue)
values = [];
if isempty(rawValue)
    return;
end
if isnumeric(rawValue) || islogical(rawValue)
    values = double(rawValue(:).');
    return;
end
if iscell(rawValue)
    for cellIndex = 1:numel(rawValue)
        values = [values, numericVectorFromValue(rawValue{cellIndex})]; %#ok<AGROW>
    end
    return;
end
if isstruct(rawValue)
    rangeMin = carbideNumericField(rawValue, ["Min", "Minimum", "Lower", "LowerLimit"]);
    rangeMax = carbideNumericField(rawValue, ["Max", "Maximum", "Upper", "UpperLimit"]);
    if isfinite(rangeMin) && isfinite(rangeMax)
        values = [rangeMin, rangeMax];
        return;
    end

    rawFields = fieldnames(rawValue);
    for rawFieldIndex = 1:numel(rawFields)
        values = [values, numericVectorFromValue(rawValue.(rawFields{rawFieldIndex}))]; %#ok<AGROW>
    end
end
end
