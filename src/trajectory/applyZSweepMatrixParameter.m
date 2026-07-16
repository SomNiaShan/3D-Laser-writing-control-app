function sweep = applyZSweepMatrixParameter(sweep, parameterName, value)
switch string(parameterName)
    case "Power (%)"
        sweep.powerPercent = double(value);
    case "Sweep Speed (mm/s)"
        sweep.sweepSpeedMmPerSecond = double(value);
    case "Return Speed (mm/s)"
        sweep.returnSpeedMmPerSecond = double(value);
    case "Repeat Count"
        sweep.repeatCount = round(double(value));
    case "Exposure Direction"
        sweep.exposureDirection = string(value);
    otherwise
        error('Unsupported Z Sweep matrix parameter: %s', char(parameterName));
end
end
