function row = batchSweepRow(template, rowIndex, baseName, parameterA, valueA, parameterB, valueB)
row = template;
row{batchColumnIndex('Enabled')} = true;
row = setRowParameter(row, parameterA, valueA);
nameParts = strings(1, 0);
nameParts(end + 1) = parameterNameToken(parameterA, valueA);
if strlength(string(parameterB)) > 0 && string(parameterB) ~= "None"
    row = setRowParameter(row, parameterB, valueB);
    nameParts(end + 1) = parameterNameToken(parameterB, valueB);
end
row{batchColumnIndex('Name')} = sanitizeFileComponent( ...
    sprintf('%s_%03d_%s', baseName, rowIndex, char(strjoin(nameParts, '_'))), ...
    sprintf('%s_%03d', baseName, rowIndex));
end

function row = setRowParameter(row, parameterName, value)
if string(parameterName) == "None" || strlength(string(parameterName)) == 0
    return;
end
row{batchColumnIndex(parameterName)} = value;
end

function token = parameterNameToken(parameterName, value)
switch string(parameterName)
    case "ConeAngleDeg"
        prefix = "beta";
    case "RadialPeriodMm"
        prefix = "rpm";
    case "RadialPeriodPx"
        prefix = "rpx";
    case "RadialCycles"
        prefix = "rc";
    case "VortexCharge"
        prefix = "v";
    case "HelicalGamma"
        prefix = "gamma";
    case "HelicalOrder"
        prefix = "order";
    case "HelicalOffsetDeg"
        prefix = "offset";
    case "OmegaInner"
        prefix = "oi";
    case "OmegaOuter"
        prefix = "oo";
    case "GlobalLensFocalMm"
        prefix = "lens";
    case "GlobalXShift2Pi"
        prefix = "gx";
    case "GlobalYShift2Pi"
        prefix = "gy";
    case "GlobalApertureRadiusPx"
        prefix = "ap";
    case "GlobalApertureCenterXpx"
        prefix = "apx";
    case "GlobalApertureCenterYpx"
        prefix = "apy";
    otherwise
        prefix = string(parameterName);
end
token = prefix + safeNumberToken(value);
end

function token = safeNumberToken(value)
if isinf(value)
    token = "inf";
    return;
end
if abs(value - round(value)) < 1e-9
    textValue = sprintf('%.0f', value);
else
    textValue = sprintf('%.6g', value);
end
textValue = strrep(textValue, '-', 'm');
textValue = strrep(textValue, '+', '');
textValue = strrep(textValue, '.', 'p');
token = string(textValue);
end
