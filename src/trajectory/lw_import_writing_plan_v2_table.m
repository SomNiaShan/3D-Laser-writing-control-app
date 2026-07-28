function trajectory = lw_import_writing_plan_v2_table( ...
        rawTable, filename, useFixedPower, fixedPower)
%LW_IMPORT_WRITING_PLAN_V2_TABLE Import the canonical point/path schema.

requiredNames = ["schema_version", "operation", "group_id", "segment_index", ...
    "laser_state", "x_mm", "y_mm", "z_mm", "x2_mm", "y2_mm", "z2_mm", ...
    "speed_mm_s", "power", "dwell_s", "pause_s", "source_recipe"];
actualNames = string(rawTable.Properties.VariableNames);
missingNames = setdiff(requiredNames, actualNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan v2 is missing columns: %s.', strjoin(missingNames, ', '));
end

schemaVersion = localNumericColumn(rawTable.schema_version, 'schema_version');
operation = localOptionColumn(rawTable.operation);
groupId = localNumericColumn(rawTable.group_id, 'group_id');
segmentIndex = localNumericColumn(rawTable.segment_index, 'segment_index');
laserState = localOptionColumn(rawTable.laser_state);
x = localNumericColumn(rawTable.x_mm, 'x_mm');
y = localNumericColumn(rawTable.y_mm, 'y_mm');
z = localNumericColumn(rawTable.z_mm, 'z_mm');
x2 = localNumericColumn(rawTable.x2_mm, 'x2_mm');
y2 = localNumericColumn(rawTable.y2_mm, 'y2_mm');
z2 = localNumericColumn(rawTable.z2_mm, 'z2_mm');
speed = localNumericColumn(rawTable.speed_mm_s, 'speed_mm_s');
filePower = localNumericColumn(rawTable.power, 'power');
dwell = localNumericColumn(rawTable.dwell_s, 'dwell_s');
pauseSeconds = localNumericColumn(rawTable.pause_s, 'pause_s');
sourceRecipe = localOptionColumn(rawTable.source_recipe);
rowCount = height(rawTable);

if any(schemaVersion ~= 2)
    error('Writing plan v2 schema_version must equal 2 on every row.');
end
if any(~ismember(operation, ["point", "path"]))
    error('Writing plan v2 operation only supports point or path.');
end
if any(~isfinite(x) | ~isfinite(y) | ~isfinite(z))
    error('Writing plan v2 start coordinates must be finite.');
end
if any(ismissing(sourceRecipe) | strlength(sourceRecipe) == 0)
    error('Writing plan v2 source_recipe values cannot be blank.');
end

if useFixedPower
    power = repmat(fixedPower, rowCount, 1);
    powerSource = "fixed_override";
else
    if any(~isfinite(filePower))
        error('Writing plan v2 power values must be finite.');
    end
    power = validatePowerPercentValues(filePower, 'Writing plan v2 power');
    powerSource = "file";
end

pointMask = operation == "point";
pathMask = operation == "path";
if any(pointMask) && any(pathMask)
    error('Writing plan v2 cannot mix point and path operations in one file.');
end

writingPlan = table( ...
    schemaVersion, operation, groupId, segmentIndex, laserState, ...
    x, y, z, x2, y2, z2, speed, power, dwell, pauseSeconds, sourceRecipe, ...
    'VariableNames', {'schemaVersion', 'operation', 'groupId', 'segmentIndex', ...
    'laserState', 'x', 'y', 'z', 'x2', 'y2', 'z2', 'speed', 'power', ...
    'dwell', 'pauseSeconds', 'sourceRecipe'});

if any(pointMask)
    localValidatePointPlan(writingPlan);
    modeSupport = "point";
    pointCount = rowCount;
    pathGroupCount = 0;
else
    lw_validate_path_plan_for_run(writingPlan);
    modeSupport = "path";
    pointCount = 0;
    pathGroupCount = numel(lw_path_plan_groups(writingPlan));
end

meta = struct( ...
    'filename', filename, ...
    'schemaVersion', 2, ...
    'powerSource', powerSource, ...
    'fixedPowerOverride', useFixedPower, ...
    'pointTimingSource', "writing_plan_v2", ...
    'pointCount', pointCount, ...
    'pathGroupCount', pathGroupCount, ...
    'pathSegmentCount', nnz(pathMask), ...
    'sourceRecipes', unique(sourceRecipe, 'stable'));
if useFixedPower
    meta.fixedPowerPercent = fixedPower;
end

trajectory = lw_make_trajectory( ...
    writingPlan.x, writingPlan.y, writingPlan.z, writingPlan.power, ...
    "writing_plan", modeSupport, meta);
trajectory.writingPlan = writingPlan;
end

function localValidatePointPlan(plan)
if any(plan.laserState ~= "dwell")
    error('Writing plan v2 point rows must use laser_state=dwell.');
end
if any(isfinite(plan.groupId) | isfinite(plan.segmentIndex))
    error('Writing plan v2 point rows cannot contain group or segment identifiers.');
end
if any(isfinite(plan.x2) | isfinite(plan.y2) | isfinite(plan.z2) | isfinite(plan.speed))
    error('Writing plan v2 point rows cannot contain path end coordinates or speed.');
end
if any(~isfinite(plan.dwell) | plan.dwell < 0)
    error('Writing plan v2 point rows must contain nonnegative dwell_s values.');
end
if any(~isfinite(plan.pauseSeconds) | plan.pauseSeconds < 0)
    error('Writing plan v2 point rows must contain nonnegative pause_s values.');
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
if any(isnan(values) & ~missingMask)
    error('%s column contains values that cannot be parsed as numbers.', columnName);
end
end

function values = localOptionColumn(value)
values = lower(strtrim(string(value(:))));
values = regexprep(values, '[\s-]+', '_');
end
