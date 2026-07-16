function job = batchJobFromDataRow(rowData, tableIndex)
job = emptyBatchJob();
job.tableIndex = tableIndex;
job.batchIndex = tableIndex;
job.enabled = logicalCell(rowData{batchColumnIndex('Enabled')});
rawName = strtrim(string(rowData{batchColumnIndex('Name')}));
if strlength(rawName) == 0
    error('Batch row %d Name is empty.', tableIndex);
end
job.name = sanitizeFileComponent(rawName, '');
if isempty(job.name)
    error('Batch row %d Name does not contain usable filename characters.', tableIndex);
end
job.notes = string(rowData{batchColumnIndex('Notes')});

options = slm_default_drill_beam_options();
options.name = job.name;
options.axiconMode = char(axiconModeCell(rowData{batchColumnIndex('AxiconMode')}, tableIndex));
options.axiconConeAngleDeg = numericCell(rowData, 'ConeAngleDeg', tableIndex, false);
options.axiconAngleDeg = options.axiconConeAngleDeg;
options.axiconRadialPeriodMm = numericCell(rowData, 'RadialPeriodMm', tableIndex, false);
options.axiconRadialPeriodPx = numericCell(rowData, 'RadialPeriodPx', tableIndex, false);
options.axiconRadialCycles = numericCell(rowData, 'RadialCycles', tableIndex, false);
options.axiconIndex = numericCell(rowData, 'AxiconIndex', tableIndex, false);
options.axiconPhysicalBaseAngleDeg = numericCell(rowData, 'PhysicalBaseAngleDeg', tableIndex, false);
options.vortexCharge = round(numericCell(rowData, 'VortexCharge', tableIndex, false));
options.helicalGamma = numericCell(rowData, 'HelicalGamma', tableIndex, false);
options.helicalOrder = round(numericCell(rowData, 'HelicalOrder', tableIndex, false));
options.helicalOffsetDeg = numericCell(rowData, 'HelicalOffsetDeg', tableIndex, false);
options.omegaInner = numericCell(rowData, 'OmegaInner', tableIndex, false);
options.omegaOuter = numericCell(rowData, 'OmegaOuter', tableIndex, false);
validateAxiconOptions(options, tableIndex);
job.options = options;

globalOptions = struct();
globalOptions.lensFocalLengthMm = numericCell(rowData, 'GlobalLensFocalMm', tableIndex, false);
globalOptions.xShiftTwoPi = numericCell(rowData, 'GlobalXShift2Pi', tableIndex, false);
globalOptions.yShiftTwoPi = numericCell(rowData, 'GlobalYShift2Pi', tableIndex, false);
apertureRadiusPx = numericCell(rowData, 'GlobalApertureRadiusPx', tableIndex, true);
if ~isfinite(apertureRadiusPx) || apertureRadiusPx <= 0
    apertureRadiusPx = Inf;
end
globalOptions.apertureRadiusPx = apertureRadiusPx;
globalOptions.apertureCenterXpx = numericCell(rowData, 'GlobalApertureCenterXpx', tableIndex, false);
globalOptions.apertureCenterYpx = numericCell(rowData, 'GlobalApertureCenterYpx', tableIndex, false);
job.globalAdjustments = globalOptions;

job.slmSettleSeconds = numericCell(rowData, 'SlmSettleSeconds', tableIndex, false);
if job.slmSettleSeconds < 0
    error('Batch row %d SlmSettleSeconds must be zero or positive.', tableIndex);
end
end

function value = logicalCell(rawValue)
if islogical(rawValue)
    value = logical(rawValue);
    if ~isscalar(value)
        value = false;
    end
    return;
end
if isnumeric(rawValue)
    value = rawValue ~= 0;
    if ~isscalar(value)
        value = false;
    end
    return;
end
textValue = lower(strtrim(string(rawValue)));
value = any(textValue == ["true", "t", "yes", "y", "on", "1", "enabled"]);
end

function mode = axiconModeCell(rawValue, tableIndex)
mode = string(strtrim(string(rawValue)));
validModes = string(batchAxiconModeItems());
if ~any(mode == validModes)
    error('Batch row %d AxiconMode must be one of: %s.', ...
        tableIndex, strjoin(cellstr(validModes), ', '));
end
end

function value = numericCell(rowData, columnName, tableIndex, allowInf)
rawValue = rowData{batchColumnIndex(columnName)};
label = sprintf('Batch row %d %s', tableIndex, columnName);
value = numericScalar(rawValue, label, allowInf);
end

function value = numericScalar(rawValue, label, allowInf)
if isnumeric(rawValue) || islogical(rawValue)
    value = double(rawValue);
else
    value = str2double(char(strtrim(string(rawValue))));
end
if ~isscalar(value) || isnan(value) || (~allowInf && ~isfinite(value))
    error('%s must be a numeric scalar.', label);
end
end

function validateAxiconOptions(options, tableIndex)
if options.axiconIndex <= 0
    error('Batch row %d AxiconIndex must be positive.', tableIndex);
end
switch string(options.axiconMode)
    case "radialPeriodMm"
        if ~isfinite(options.axiconRadialPeriodMm) || options.axiconRadialPeriodMm == 0
            error('Batch row %d RadialPeriodMm must be finite and nonzero.', tableIndex);
        end
    case "radialPeriodPx"
        if ~isfinite(options.axiconRadialPeriodPx) || options.axiconRadialPeriodPx == 0
            error('Batch row %d RadialPeriodPx must be finite and nonzero.', tableIndex);
        end
    case "radialCycles"
        if ~isfinite(options.axiconRadialCycles)
            error('Batch row %d RadialCycles must be finite.', tableIndex);
        end
    case "physicalEquivalent"
        if ~isfinite(options.axiconPhysicalBaseAngleDeg)
            error('Batch row %d PhysicalBaseAngleDeg must be finite.', tableIndex);
        end
end
end
