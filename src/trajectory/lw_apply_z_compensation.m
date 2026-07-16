function trajectory = lw_apply_z_compensation(trajectory, marks, referencePoint)
%LW_APPLY_Z_COMPENSATION Apply 3-point plane-based Z leveling.

plane = lw_leveling_plane_from_marks(marks);
if nargin < 3 || isempty(referencePoint)
    referenceXY = plane.anchor(1:2);
elseif isstruct(referencePoint)
    referenceXY = [referencePoint.x, referencePoint.y];
else
    referenceXY = referencePoint(1:2);
end

referenceZ = plane.a * referenceXY(1) + plane.b * referenceXY(2) + plane.c;
compensation = plane.a * trajectory.x + plane.b * trajectory.y + plane.c - referenceZ;
trajectory.z = trajectory.z + compensation;

if isfield(trajectory, 'cutPlan') && istable(trajectory.cutPlan)
    trajectory.cutPlan = localCompensateCutPlan(trajectory.cutPlan, plane, referenceZ);
end
end

function cutPlan = localCompensateCutPlan(cutPlan, plane, referenceZ)
coordinateSets = { ...
    {'x', 'y', 'z'}, ...
    {'x2', 'y2', 'z2'}, ...
    {'leadX', 'leadY', 'leadZ'}, ...
    {'exitX', 'exitY', 'exitZ'}};

for i = 1:numel(coordinateSets)
    names = coordinateSets{i};
    if all(ismember(names, cutPlan.Properties.VariableNames))
        compensation = plane.a * cutPlan.(names{1}) + plane.b * cutPlan.(names{2}) + plane.c - referenceZ;
        cutPlan.(names{3}) = cutPlan.(names{3}) + compensation;
    end
end
end
