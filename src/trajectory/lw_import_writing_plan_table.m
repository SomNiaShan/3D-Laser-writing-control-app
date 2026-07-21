function trajectory = lw_import_writing_plan_table(filename)
%LW_IMPORT_WRITING_PLAN_TABLE Import Point Cloud Generator writing-plan CSV files.

rawTable = localReadDelimitedTextTable(filename);
if isempty(rawTable) || height(rawTable) == 0
    error('Writing plan file is empty.');
end

requiredNames = ["mode", "x_mm", "y_mm", "z_mm", "x2_mm", "y2_mm", "z2_mm", ...
    "power", "dwell_s", "scan_speed_mm_s", "pause_s"];
actualNames = string(rawTable.Properties.VariableNames);
missingNames = setdiff(requiredNames, actualNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan file is missing columns: %s.', strjoin(missingNames, ', '));
end

rowCount = height(rawTable);
mode = localNormalizeModes(rawTable.mode);
x = localNumericColumn(rawTable.x_mm, 'x_mm');
y = localNumericColumn(rawTable.y_mm, 'y_mm');
z = localNumericColumn(rawTable.z_mm, 'z_mm');
x2 = localNumericColumn(rawTable.x2_mm, 'x2_mm');
y2 = localNumericColumn(rawTable.y2_mm, 'y2_mm');
z2 = localNumericColumn(rawTable.z2_mm, 'z2_mm');
power = localNumericColumn(rawTable.power, 'power');
dwell = localNumericColumn(rawTable.dwell_s, 'dwell_s');
scanSpeed = localNumericColumn(rawTable.scan_speed_mm_s, 'scan_speed_mm_s');
pauseSeconds = localNumericColumn(rawTable.pause_s, 'pause_s');
leadX = localOptionalNumericColumn(rawTable, 'lead_x_mm', rowCount);
leadY = localOptionalNumericColumn(rawTable, 'lead_y_mm', rowCount);
leadZ = localOptionalNumericColumn(rawTable, 'lead_z_mm', rowCount);
exitX = localOptionalNumericColumn(rawTable, 'exit_x_mm', rowCount);
exitY = localOptionalNumericColumn(rawTable, 'exit_y_mm', rowCount);
exitZ = localOptionalNumericColumn(rawTable, 'exit_z_mm', rowCount);
leadSpeed = localOptionalNumericColumn(rawTable, 'lead_speed_mm_s', rowCount);
cutMask = mode == "cut";
[cutGroupId, cutGroupSegment] = localCutGroupColumns(rawTable, actualNames, cutMask);

if any(~isfinite(x) | ~isfinite(y) | ~isfinite(z))
    error('Writing plan x_mm, y_mm, and z_mm columns must be finite.');
end
if any(~isfinite(power))
    error('Writing plan power column must be finite.');
end
power = validatePowerPercentValues(power, 'Writing plan power column');
if any(isfinite(pauseSeconds) & pauseSeconds < 0)
    error('Writing plan pause_s values cannot be negative.');
end

if any(cutMask)
    if any(~isfinite(x2(cutMask)) | ~isfinite(y2(cutMask)) | ~isfinite(z2(cutMask)))
        error('Cut rows must contain finite x2_mm, y2_mm, and z2_mm values.');
    end
    if any(~isfinite(leadX(cutMask)) | ~isfinite(leadY(cutMask)) | ~isfinite(leadZ(cutMask)) | ...
            ~isfinite(exitX(cutMask)) | ~isfinite(exitY(cutMask)) | ~isfinite(exitZ(cutMask)))
        error('Cut rows must contain finite lead_* and exit_* coordinates.');
    end
    if any(~isfinite(scanSpeed(cutMask)) | scanSpeed(cutMask) <= 0)
        error('Cut rows must contain positive scan_speed_mm_s values.');
    end
    missingLeadSpeed = isnan(leadSpeed(cutMask));
    cutIndices = find(cutMask);
    leadSpeed(cutIndices(missingLeadSpeed)) = scanSpeed(cutIndices(missingLeadSpeed));
    if any(~isfinite(leadSpeed(cutMask)) | leadSpeed(cutMask) <= 0)
        error('Cut rows must contain positive lead_speed_mm_s values.');
    end
end

pointMask = mode == "point";
if any(pointMask) && any(~isfinite(dwell(pointMask)) | dwell(pointMask) < 0)
    error('Point rows must contain nonnegative dwell_s values.');
end

plan = table(mode, x, y, z, x2, y2, z2, power, dwell, scanSpeed, pauseSeconds, ...
    leadX, leadY, leadZ, exitX, exitY, exitZ, leadSpeed, cutGroupId, cutGroupSegment, ...
    'VariableNames', {'mode', 'x', 'y', 'z', 'x2', 'y2', 'z2', ...
    'power', 'dwell', 'scanSpeed', 'pauseSeconds', ...
    'leadX', 'leadY', 'leadZ', 'exitX', 'exitY', 'exitZ', ...
    'leadSpeed', 'cutGroupId', 'cutGroupSegment'});

if any(cutMask)
    lw_validate_cut_plan_rows_for_run(plan);
    modeSupport = "cut";
elseif any(pointMask)
    modeSupport = "point+stream";
else
    modeSupport = "stream";
end

meta = struct( ...
    'filename', filename, ...
    'powerSource', "file", ...
    'pointTimingSource', "writing_plan", ...
    'pointCount', nnz(mode == "point"), ...
    'scanCount', nnz(mode == "scan"), ...
    'cutCount', nnz(mode == "cut"));
trajectory = lw_make_trajectory(x, y, z, power, "writing_plan", modeSupport, meta);
trajectory.cutPlan = plan;
end

function modes = localNormalizeModes(value)
modes = lower(strtrim(string(value)));
modes = regexprep(modes, '[\s-]+', '_');
modes(modes == "point_dwell") = "point";
modes(modes == "axis_scan") = "scan";
modes(modes == "cut_scan" | modes == "hexagon_cut" | ...
    modes == "hexagon_release_cut" | modes == "hexagon_release_cut_array") = "cut";
if any(~ismember(modes, ["point", "scan", "cut"]))
    error('Writing plan mode column only supports point, scan, or cut.');
end
end

function values = localNumericColumn(value, columnName)
if isnumeric(value)
    values = double(value(:));
    return;
end

textValue = strtrim(string(value(:)));
values = str2double(textValue);
missingMask = ismissing(textValue) | strlength(textValue) == 0 | ...
    strcmpi(textValue, "NaN") | strcmpi(textValue, "NA");
values(missingMask) = nan;
badText = isnan(values) & ~missingMask;
if any(badText)
    error('%s column contains values that cannot be parsed as numbers.', columnName);
end
end

function values = localOptionalNumericColumn(rawTable, columnName, rowCount)
if any(strcmp(rawTable.Properties.VariableNames, columnName))
    values = localNumericColumn(rawTable.(columnName), columnName);
else
    values = nan(rowCount, 1);
end
end

function [cutGroupId, cutGroupSegment] = localCutGroupColumns(rawTable, actualNames, cutMask)
rowCount = numel(cutMask);
hasGroupId = any(strcmp(actualNames, 'cut_group_id'));
hasGroupSegment = any(strcmp(actualNames, 'cut_group_segment'));
if hasGroupSegment && ~hasGroupId
    error('Writing plan has cut_group_segment but is missing cut_group_id.');
end

cutGroupId = (1:rowCount).';
cutGroupSegment = ones(rowCount, 1);
if ~hasGroupId
    return;
end

cutGroupId = localOptionalNumericColumn(rawTable, 'cut_group_id', rowCount);
missingGroupId = isnan(cutGroupId);
if any(cutMask & missingGroupId)
    error('Cut rows must contain finite cut_group_id values when the cut_group_id column is present.');
end
cutGroupId(~cutMask & missingGroupId) = find(~cutMask & missingGroupId);
localRequirePositiveIntegers(cutGroupId(cutMask), 'cut_group_id');
cutGroupId(cutMask) = round(cutGroupId(cutMask));

if hasGroupSegment
    cutGroupSegment = localOptionalNumericColumn(rawTable, 'cut_group_segment', rowCount);
    missingSegment = isnan(cutGroupSegment);
    if any(cutMask & missingSegment)
        error('Cut rows must contain finite cut_group_segment values when the cut_group_segment column is present.');
    end
    cutGroupSegment(~cutMask & missingSegment) = 1;
    localRequirePositiveIntegers(cutGroupSegment(cutMask), 'cut_group_segment');
    cutGroupSegment(cutMask) = round(cutGroupSegment(cutMask));
else
    cutGroupSegment = localAutoCutGroupSegments(cutGroupId, cutMask);
end
end

function segments = localAutoCutGroupSegments(groupIds, cutMask)
segments = ones(numel(groupIds), 1);
for iRow = 1:numel(groupIds)
    if ~cutMask(iRow)
        continue;
    end
    sameGroupBefore = cutMask(1:iRow) & (groupIds(1:iRow) == groupIds(iRow));
    segments(iRow) = nnz(sameGroupBefore);
end
end

function localRequirePositiveIntegers(values, columnName)
badMask = ~isfinite(values) | values < 1 | abs(values - round(values)) > 1e-9;
if any(badMask)
    error('%s values must be positive integers.', columnName);
end
end

function rawTable = localReadDelimitedTextTable(filename)
fileText = fileread(filename);
if isempty(fileText)
    rawTable = table();
    return;
end

if fileText(1) == char(65279)
    fileText(1) = [];
end
fileText = strrep(fileText, [char(13), newline], newline);
fileText = strrep(fileText, char(13), newline);

lines = regexp(fileText, '\n', 'split');
while ~isempty(lines) && isempty(lines{end})
    lines(end) = [];
end
if isempty(lines)
    rawTable = table();
    return;
end

headerLine = lines{1};
delimiter = localDetectDelimiter(headerLine);
headers = strtrim(localSplitDelimitedLine(headerLine, delimiter));
if isempty(headers) || any(cellfun(@isempty, headers))
    error('Writing plan file header contains empty column names.');
end
if numel(unique(headers, 'stable')) ~= numel(headers)
    error('Writing plan file header contains duplicate column names.');
end

rowCount = numel(lines) - 1;
columns = cell(1, numel(headers));
for columnIndex = 1:numel(headers)
    columns{columnIndex} = strings(rowCount, 1);
end

for rowIndex = 1:rowCount
    values = localSplitDelimitedLine(lines{rowIndex + 1}, delimiter);
    if numel(values) < numel(headers)
        values(end + 1:numel(headers)) = {''};
    elseif numel(values) > numel(headers)
        error('Writing plan row %d has %d columns, expected %d.', ...
            rowIndex + 1, numel(values), numel(headers));
    end

    for columnIndex = 1:numel(headers)
        columns{columnIndex}(rowIndex) = string(values{columnIndex});
    end
end

rawTable = table(columns{:}, 'VariableNames', headers);
end

function delimiter = localDetectDelimiter(headerLine)
delimiter = ',';
if count(string(headerLine), sprintf('\t')) > count(string(headerLine), ",")
    delimiter = sprintf('\t');
end
end

function values = localSplitDelimitedLine(line, delimiter)
values = strsplit(line, delimiter, 'CollapseDelimiters', false);
end
