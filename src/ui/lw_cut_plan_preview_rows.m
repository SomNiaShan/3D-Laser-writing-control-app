function [previewRows, isSampled] = lw_cut_plan_preview_rows(cutRows, maxRows)
%LW_CUT_PLAN_PREVIEW_ROWS Sample cut rows while preserving cut groups.

if nargin < 2 || isempty(maxRows)
    maxRows = height(cutRows);
end
maxRows = max(1, round(double(maxRows)));
isSampled = false;

if height(cutRows) <= maxRows
    previewRows = cutRows;
    return;
end

groups = lw_cut_plan_groups(cutRows);
if isempty(groups)
    previewRows = cutRows([], :);
    return;
end

isSampled = true;
selectedGroupCount = min(numel(groups), maxRows);
while selectedGroupCount > 1
    groupIndices = lw_preview_sample_indices(numel(groups), selectedGroupCount);
    previewRows = localRowsForGroups(groups, groupIndices);
    if height(previewRows) <= maxRows
        return;
    end
    selectedGroupCount = max(1, floor(selectedGroupCount / 2));
end

middleGroup = max(1, round(numel(groups) / 2));
previewRows = groups(middleGroup).rows;
end

function rows = localRowsForGroups(groups, groupIndices)
rows = groups(groupIndices(1)).rows;
for i = 2:numel(groupIndices)
    rows = [rows; groups(groupIndices(i)).rows]; %#ok<AGROW>
end
end
