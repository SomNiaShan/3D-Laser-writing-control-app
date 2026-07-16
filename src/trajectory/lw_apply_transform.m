function trajectory = lw_apply_transform(trajectory, origin, magnification)
%LW_APPLY_TRANSFORM Apply origin shift and per-axis magnification.

trajectory.x = trajectory.x .* magnification.x + origin.x;
trajectory.y = trajectory.y .* magnification.y + origin.y;
trajectory.z = trajectory.z .* magnification.z + origin.z;

if isfield(trajectory, 'cutPlan') && istable(trajectory.cutPlan)
    trajectory.cutPlan = localTransformCutPlan(trajectory.cutPlan, origin, magnification);
end
end

function cutPlan = localTransformCutPlan(cutPlan, origin, magnification)
xFields = {'x', 'x2', 'leadX', 'exitX'};
yFields = {'y', 'y2', 'leadY', 'exitY'};
zFields = {'z', 'z2', 'leadZ', 'exitZ'};

for i = 1:numel(xFields)
    fieldName = xFields{i};
    if ismember(fieldName, cutPlan.Properties.VariableNames)
        cutPlan.(fieldName) = cutPlan.(fieldName) .* magnification.x + origin.x;
    end
end
for i = 1:numel(yFields)
    fieldName = yFields{i};
    if ismember(fieldName, cutPlan.Properties.VariableNames)
        cutPlan.(fieldName) = cutPlan.(fieldName) .* magnification.y + origin.y;
    end
end
for i = 1:numel(zFields)
    fieldName = zFields{i};
    if ismember(fieldName, cutPlan.Properties.VariableNames)
        cutPlan.(fieldName) = cutPlan.(fieldName) .* magnification.z + origin.z;
    end
end
end
