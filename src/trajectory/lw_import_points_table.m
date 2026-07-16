function trajectory = lw_import_points_table(filename, fixedPower)
%LW_IMPORT_POINTS_TABLE Import a writing plan or fixed-order numeric points table.

if nargin < 2
    fixedPower = nan;
end

if localLooksLikeWritingPlan(filename)
    trajectory = lw_import_writing_plan_table(filename);
    return;
end

data = readmatrix(filename);
if isempty(data) || size(data, 2) < 3
    error('Input file must contain fixed-order numeric columns: X, Y, Z, and optional power.');
end

x = data(:, 1);
y = data(:, 2);
z = data(:, 3);
if any(~isfinite(x) | ~isfinite(y) | ~isfinite(z))
    error('Input XYZ columns must contain only finite numeric values.');
end

if size(data, 2) == 3
    power = localFixedPowerColumn(fixedPower, numel(x));
    powerSource = "plan";
elseif size(data, 2) >= 4
    power = validatePowerPercentValues(data(:, 4), 'Input power column');
    powerSource = "file";
else
    error('Input file has no power column. Set XYZ-only Power (%) on the Plan tab.');
end

meta = struct('filename', filename, 'powerSource', powerSource);
trajectory = lw_make_trajectory(x, y, z, power, "imported_points", "point+stream", meta);
end

function power = localFixedPowerColumn(fixedPower, rowCount)
fixedPower = validatePowerPercent(fixedPower, 'XYZ-only power');
power = repmat(fixedPower, rowCount, 1);
end

function tf = localLooksLikeWritingPlan(filename)
try
    fid = fopen(filename, 'r');
    if fid < 0
        tf = false;
        return;
    end
    cleaner = onCleanup(@() fclose(fid));
    headerLine = fgetl(fid);
    if ~ischar(headerLine)
        tf = false;
        return;
    end
    if ~isempty(headerLine) && headerLine(1) == char(65279)
        headerLine(1) = [];
    end
    delimiter = ',';
    if count(string(headerLine), sprintf('\t')) > count(string(headerLine), ",")
        delimiter = sprintf('\t');
    end
    names = lower(strtrim(string(strsplit(headerLine, delimiter, 'CollapseDelimiters', false))));
    requiredNames = ["mode", "x_mm", "y_mm", "z_mm", "power"];
    tf = all(ismember(requiredNames, names));
catch
    tf = false;
end
end
