function [previewRows, isSampled] = lw_path_plan_preview_rows(pathRows, maxRows)
%LW_PATH_PLAN_PREVIEW_ROWS Sample complete path groups for preview.

if nargin < 2 || isempty(maxRows)
    maxRows = height(pathRows);
end
maxRows = max(1, round(double(maxRows)));
isSampled = false;
if height(pathRows) <= maxRows
    previewRows = pathRows;
    return;
end

groups = lw_path_plan_groups(pathRows);
if isempty(groups)
    previewRows = pathRows([], :);
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
previewRows = groups(max(1, round(numel(groups) / 2))).rows;
end

function rows = localRowsForGroups(groups, groupIndices)
rows = groups(groupIndices(1)).rows;
for index = 2:numel(groupIndices)
    rows = [rows; groups(groupIndices(index)).rows]; %#ok<AGROW>
end
end
