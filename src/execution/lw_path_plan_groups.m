function groups = lw_path_plan_groups(writingPlan)
%LW_PATH_PLAN_GROUPS Return consecutive executable path groups.

if isempty(writingPlan) || ~istable(writingPlan)
    groups = localEmptyGroups(table());
    return;
end
requiredNames = {'operation', 'groupId'};
missingNames = setdiff(requiredNames, writingPlan.Properties.VariableNames, 'stable');
if ~isempty(missingNames)
    error('Writing plan is missing internal columns: %s.', strjoin(missingNames, ', '));
end

pathRows = writingPlan(string(writingPlan.operation) == "path", :);
if height(pathRows) == 0
    groups = localEmptyGroups(pathRows);
    return;
end

groupIds = pathRows.groupId(:);
groupStarts = [1; find(groupIds(2:end) ~= groupIds(1:end - 1)) + 1];
groupEnds = [groupStarts(2:end) - 1; height(pathRows)];
groups = repmat(localEmptyGroup(pathRows), numel(groupStarts), 1);
for groupIndex = 1:numel(groupStarts)
    startRow = groupStarts(groupIndex);
    endRow = groupEnds(groupIndex);
    rows = pathRows(startRow:endRow, :);
    groups(groupIndex) = struct( ...
        'id', rows.groupId(1), ...
        'startRow', startRow, ...
        'endRow', endRow, ...
        'rowCount', height(rows), ...
        'rows', rows);
end
end

function groups = localEmptyGroups(rows)
groups = localEmptyGroup(rows);
groups(1) = [];
end

function group = localEmptyGroup(rows)
group = struct('id', NaN, 'startRow', 0, 'endRow', 0, ...
    'rowCount', 0, 'rows', rows);
end
