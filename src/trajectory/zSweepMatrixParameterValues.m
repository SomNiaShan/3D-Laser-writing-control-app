function values = zSweepMatrixParameterValues(parameterName, rawValue)
switch string(parameterName)
    case "Power (%)"
        values = numericList(rawValue, 'Z Sweep matrix power values', false);
    case "Sweep Speed (mm/s)"
        values = numericList(rawValue, 'Z Sweep matrix sweep speed values', true);
    case "Return Speed (mm/s)"
        values = numericList(rawValue, 'Z Sweep matrix return speed values', true);
    case "Repeat Count"
        values = numericList(rawValue, 'Z Sweep matrix repeat count values', true);
        if any(abs(values - round(values)) > 1e-9)
            error('Z Sweep matrix repeat count values must be positive integers.');
        end
        values = round(values);
    case "Exposure Direction"
        values = zSweepMatrixDirectionList(rawValue);
    otherwise
        error('Unsupported Z Sweep matrix parameter: %s', char(parameterName));
end
end
