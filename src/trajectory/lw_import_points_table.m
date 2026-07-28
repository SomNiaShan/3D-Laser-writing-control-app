function trajectory = lw_import_points_table(filename, useFixedPower, fixedPower)
%LW_IMPORT_POINTS_TABLE Import a writing plan or fixed-order numeric points table.

if nargin < 2
    useFixedPower = false;
end
if nargin < 3
    fixedPower = nan;
end
[useFixedPower, fixedPower] = localFixedPowerOptions(useFixedPower, fixedPower);

if localLooksLikeWritingPlan(filename)
    trajectory = lw_import_writing_plan_table(filename, useFixedPower, fixedPower);
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

if useFixedPower
    power = repmat(fixedPower, numel(x), 1);
    powerSource = "fixed_override";
elseif size(data, 2) >= 4
    power = validatePowerPercentValues(data(:, 4), 'Input power column');
    powerSource = "file";
else
    error('lw:MissingInputPower', ...
        'Input file has no power column. Enable Use Fixed Power or provide an XYZP file.');
end

meta = struct( ...
    'filename', filename, ...
    'powerSource', powerSource, ...
    'fixedPowerOverride', useFixedPower);
if useFixedPower
    meta.fixedPowerPercent = fixedPower;
end
trajectory = lw_make_trajectory(x, y, z, power, "imported_points", "point+stream", meta);
end

function [useFixedPower, fixedPower] = localFixedPowerOptions(useFixedPower, fixedPower)
isBooleanScalar = (islogical(useFixedPower) || isnumeric(useFixedPower)) && ...
    isreal(useFixedPower) && isscalar(useFixedPower) && isfinite(useFixedPower) && ...
    any(double(useFixedPower) == [0, 1]);
if ~isBooleanScalar
    error('lw:InvalidFixedPowerOverride', ...
        'Use Fixed Power must be a scalar logical value.');
end

useFixedPower = logical(useFixedPower);
if useFixedPower
    fixedPower = validatePowerPercent(fixedPower, 'Fixed power override');
else
    fixedPower = nan;
end
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
    legacyNames = ["mode", "x_mm", "y_mm", "z_mm", "power"];
    v2Names = ["schema_version", "operation", "x_mm", "y_mm", "z_mm", "power"];
    tf = all(ismember(legacyNames, names)) || all(ismember(v2Names, names));
catch
    tf = false;
end
end
