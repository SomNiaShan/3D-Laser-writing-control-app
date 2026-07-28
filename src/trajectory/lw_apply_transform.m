function trajectory = lw_apply_transform(trajectory, origin, magnification)
%LW_APPLY_TRANSFORM Apply origin shift and per-axis magnification.

trajectory.x = trajectory.x .* magnification.x + origin.x;
trajectory.y = trajectory.y .* magnification.y + origin.y;
trajectory.z = trajectory.z .* magnification.z + origin.z;

if isfield(trajectory, 'writingPlan') && istable(trajectory.writingPlan)
    trajectory.writingPlan = localTransformWritingPlan( ...
        trajectory.writingPlan, origin, magnification);
end
end

function writingPlan = localTransformWritingPlan(writingPlan, origin, magnification)
xFields = {'x', 'x2'};
yFields = {'y', 'y2'};
zFields = {'z', 'z2'};

for i = 1:numel(xFields)
    fieldName = xFields{i};
    if ismember(fieldName, writingPlan.Properties.VariableNames)
        writingPlan.(fieldName) = writingPlan.(fieldName) .* magnification.x + origin.x;
    end
end
for i = 1:numel(yFields)
    fieldName = yFields{i};
    if ismember(fieldName, writingPlan.Properties.VariableNames)
        writingPlan.(fieldName) = writingPlan.(fieldName) .* magnification.y + origin.y;
    end
end
for i = 1:numel(zFields)
    fieldName = zFields{i};
    if ismember(fieldName, writingPlan.Properties.VariableNames)
        writingPlan.(fieldName) = writingPlan.(fieldName) .* magnification.z + origin.z;
    end
end
end
