function groups = lw_cut_plan_groups(cutPlan)
%LW_CUT_PLAN_GROUPS Return consecutive executable cut groups.

if isempty(cutPlan) || ~istable(cutPlan)
    groups = localEmptyGroups(table());
    return;
end
if ~ismember('mode', cutPlan.Properties.VariableNames)
    error('Cut plan is missing internal column: mode.');
end

cutRows = cutPlan(string(cutPlan.mode) == "cut", :);
if isempty(cutRows) || height(cutRows) == 0
    groups = localEmptyGroups(cutRows);
    return;
end

cutRows = localEnsureGroupColumns(cutRows);
groupIds = cutRows.cutGroupId(:);
groupStarts = [1; find(groupIds(2:end) ~= groupIds(1:end - 1)) + 1];
groupEnds = [groupStarts(2:end) - 1; height(cutRows)];
groupCount = numel(groupStarts);

groups = localEmptyGroups(cutRows);
groups = repmat(groups, groupCount, 1);
for iGroup = 1:groupCount
    startRow = groupStarts(iGroup);
    endRow = groupEnds(iGroup);
    rows = cutRows(startRow:endRow, :);
    groups(iGroup) = struct( ...
        'id', rows.cutGroupId(1), ...
        'startRow', startRow, ...
        'endRow', endRow, ...
        'rowCount', height(rows), ...
        'rows', rows);
end
end

function groups = localEmptyGroups(cutRows)
groups = struct( ...
    'id', NaN, ...
    'startRow', 0, ...
    'endRow', 0, ...
    'rowCount', 0, ...
    'rows', cutRows);
groups(1) = [];
end

function cutRows = localEnsureGroupColumns(cutRows)
if ~ismember('cutGroupId', cutRows.Properties.VariableNames)
    cutRows.cutGroupId = (1:height(cutRows)).';
end
if ~ismember('cutGroupSegment', cutRows.Properties.VariableNames)
    cutRows.cutGroupSegment = localSequentialSegments(cutRows.cutGroupId);
end
end

function segments = localSequentialSegments(groupIds)
segments = ones(numel(groupIds), 1);
for iRow = 1:numel(groupIds)
    segments(iRow) = nnz(groupIds(1:iRow) == groupIds(iRow));
end
end
