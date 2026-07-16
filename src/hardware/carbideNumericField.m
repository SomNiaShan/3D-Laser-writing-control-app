function value = carbideNumericField(source, fieldNames)
value = NaN;
rawValue = carbideField(source, fieldNames, []);
numericValues = numericVectorFromValue(rawValue);
if ~isempty(numericValues)
    value = numericValues(1);
end
end
