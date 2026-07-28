function groups = lw_validate_path_plan_for_run(writingPlan)
%LW_VALIDATE_PATH_PLAN_FOR_RUN Validate canonical path rows and groups.

requiredNames = {'operation', 'groupId', 'segmentIndex', 'laserState', ...
    'x', 'y', 'z', 'x2', 'y2', 'z2', 'speed', 'power', ...
    'dwell', 'pauseSeconds', 'sourceRecipe'};
missingNames = setdiff(requiredNames, writingPlan.Properties.VariableNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan is missing internal columns: %s.', strjoin(missingNames, ', '));
end

pathRows = writingPlan(string(writingPlan.operation) == "path", :);
if height(pathRows) == 0
    error('Path Plan Mode requires at least one path segment.');
end
if any(string(pathRows.laserState) ~= "on" & string(pathRows.laserState) ~= "off")
    error('Path plan laserState values must be on or off.');
end

finiteColumns = {'groupId', 'segmentIndex', 'x', 'y', 'z', ...
    'x2', 'y2', 'z2', 'speed', 'power', 'pauseSeconds'};
for columnIndex = 1:numel(finiteColumns)
    values = pathRows.(finiteColumns{columnIndex});
    if any(~isfinite(values))
        error('Path plan column %s contains non-finite values.', finiteColumns{columnIndex});
    end
end
if any(pathRows.speed <= 0)
    error('Path plan speed values must be positive.');
end
if any(pathRows.pauseSeconds < 0)
    error('Path plan pauseSeconds values must be nonnegative.');
end
if any(isfinite(pathRows.dwell))
    error('Path plan dwell values must be empty.');
end
segmentLength = sqrt((pathRows.x2 - pathRows.x) .^ 2 + ...
    (pathRows.y2 - pathRows.y) .^ 2 + (pathRows.z2 - pathRows.z) .^ 2);
if any(segmentLength <= 1e-12)
    error('Path plan segments must have nonzero length.');
end

groups = lw_path_plan_groups(writingPlan);
ids = arrayfun(@(group) group.id, groups);
localRequirePositiveIntegers(ids, 'groupId');
if numel(unique(ids, 'stable')) ~= numel(ids)
    error('Path plan groupId values must occupy contiguous row blocks.');
end
for groupIndex = 1:numel(groups)
    localValidateGroup(groups(groupIndex));
end
end

function localValidateGroup(group)
rows = group.rows;
localRequirePositiveIntegers(rows.segmentIndex, 'segmentIndex');
if any(rows.segmentIndex ~= (1:height(rows)).')
    error('Path group %g segmentIndex values must be 1..N in file order.', group.id);
end
if height(rows) > 1
    deltas = abs([ ...
        rows.x2(1:end - 1) - rows.x(2:end), ...
        rows.y2(1:end - 1) - rows.y(2:end), ...
        rows.z2(1:end - 1) - rows.z(2:end)]);
    badIndex = find(max(deltas, [], 2) > 1e-6, 1);
    if ~isempty(badIndex)
        error('lw:WritingPlanV2DiscontinuousGroup', ...
            'Path group %g segment %d does not end at the next segment start.', ...
            group.id, badIndex);
    end
end
if ~any(string(rows.laserState) == "on")
    error('Path group %g must contain at least one laser-on segment.', group.id);
end
localRequireConstant(rows.power, 'power', group.id);
localRequireConstant(rows.pauseSeconds, 'pauseSeconds', group.id);
if any(string(rows.sourceRecipe) ~= string(rows.sourceRecipe(1)))
    error('Path group %g must use one sourceRecipe.', group.id);
end
end

function localRequirePositiveIntegers(values, label)
if any(~isfinite(values) | values < 1 | abs(values - round(values)) > 1e-9)
    error('Path plan %s values must be positive integers.', label);
end
end

function localRequireConstant(values, label, groupId)
if max(abs(values(:) - values(1))) > 1e-9
    error('Path group %g has inconsistent %s values.', groupId, label);
end
end
