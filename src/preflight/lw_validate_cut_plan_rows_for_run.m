function groups = lw_validate_cut_plan_rows_for_run(cutPlan)
%LW_VALIDATE_CUT_PLAN_ROWS_FOR_RUN Validate cut rows and continuous groups.

requiredNames = {'mode', 'x', 'y', 'z', 'x2', 'y2', 'z2', ...
    'leadX', 'leadY', 'leadZ', 'exitX', 'exitY', 'exitZ', ...
    'power', 'scanSpeed', 'leadSpeed', 'pauseSeconds'};
missingNames = setdiff(requiredNames, cutPlan.Properties.VariableNames, 'stable');
if ~isempty(missingNames)
    error('Cut plan is missing internal columns: %s.', strjoin(missingNames, ', '));
end

hasGroupId = ismember('cutGroupId', cutPlan.Properties.VariableNames);
hasGroupSegment = ismember('cutGroupSegment', cutPlan.Properties.VariableNames);
if hasGroupSegment && ~hasGroupId
    error('Cut plan has cutGroupSegment but is missing cutGroupId.');
end

cutRows = cutPlan(string(cutPlan.mode) == "cut", :);
if isempty(cutRows) || height(cutRows) == 0
    error('Cut Plan Mode requires at least one cut row.');
end

finiteColumns = {'x', 'y', 'z', 'x2', 'y2', 'z2', ...
    'leadX', 'leadY', 'leadZ', 'exitX', 'exitY', 'exitZ', 'power'};
for i = 1:numel(finiteColumns)
    values = cutRows.(finiteColumns{i});
    if any(~isfinite(values))
        error('Cut plan column %s contains non-finite values.', finiteColumns{i});
    end
end
if any(~isfinite(cutRows.scanSpeed) | cutRows.scanSpeed <= 0)
    error('Cut plan scanSpeed values must be positive.');
end
if any(~isfinite(cutRows.leadSpeed) | cutRows.leadSpeed <= 0)
    error('Cut plan leadSpeed values must be positive.');
end
if any(~isfinite(cutRows.pauseSeconds) | cutRows.pauseSeconds < 0)
    error('Cut plan pauseSeconds values must be nonnegative.');
end

groups = lw_cut_plan_groups(cutPlan);
localValidateGroupIdsAreContiguous(groups);
for iGroup = 1:numel(groups)
    localValidateGroup(groups(iGroup));
end
end

function localValidateGroupIdsAreContiguous(groups)
ids = arrayfun(@(group) group.id, groups);
if any(~localIsPositiveInteger(ids))
    error('Cut plan cutGroupId values must be positive integers.');
end
if numel(unique(ids, 'stable')) ~= numel(ids)
    error('Cut plan cutGroupId values must be contiguous; repeated group ids cannot reappear later in the file.');
end
end

function localValidateGroup(group)
rows = group.rows;
segments = rows.cutGroupSegment(:);
if any(~localIsPositiveInteger(segments))
    error('Cut group %s has non-positive or non-integer cutGroupSegment values.', localGroupIdText(group.id));
end

expectedSegments = (1:height(rows)).';
if any(segments ~= expectedSegments)
    error('Cut group %s cutGroupSegment values must be 1..N in file order.', localGroupIdText(group.id));
end

if height(rows) > 1
    deltas = abs([ ...
        rows.x2(1:end - 1) - rows.x(2:end), ...
        rows.y2(1:end - 1) - rows.y(2:end), ...
        rows.z2(1:end - 1) - rows.z(2:end)]);
    maxDelta = max(deltas, [], 2);
    badIndex = find(maxDelta > 1e-6, 1, 'first');
    if ~isempty(badIndex)
        error('Cut group %s segment %d does not end at the next segment start.', ...
            localGroupIdText(group.id), badIndex);
    end
end

localRequireConstant(rows.power, 'power', group.id);
localRequireConstant(rows.leadSpeed, 'leadSpeed', group.id);
localRequireConstant(rows.pauseSeconds, 'pauseSeconds', group.id);
end

function localRequireConstant(values, label, groupId)
if max(abs(values(:) - values(1))) > 1e-9
    error('Cut group %s has inconsistent %s values.', localGroupIdText(groupId), label);
end
end

function mask = localIsPositiveInteger(values)
mask = isfinite(values) & values >= 1 & abs(values - round(values)) <= 1e-9;
end

function textValue = localGroupIdText(groupId)
textValue = sprintf('%g', groupId);
end
