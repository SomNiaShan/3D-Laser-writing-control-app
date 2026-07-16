function textValue = zSweepMatrixValueText(parameterName, value)
if string(parameterName) == "Exposure Direction"
    textValue = string(value);
    return;
end

    textValue = string(formatCompactNumberLocal(double(value)));
end
