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

if isfield(trajectory, 'writingPlan') && istable(trajectory.writingPlan)
    trajectory.writingPlan = localCompensateWritingPlan( ...
        trajectory.writingPlan, plane, referenceZ);
end
end

function writingPlan = localCompensateWritingPlan(writingPlan, plane, referenceZ)
coordinateSets = { ...
    {'x', 'y', 'z'}, ...
    {'x2', 'y2', 'z2'}};

for i = 1:numel(coordinateSets)
    names = coordinateSets{i};
    if all(ismember(names, writingPlan.Properties.VariableNames))
        compensation = plane.a * writingPlan.(names{1}) + ...
            plane.b * writingPlan.(names{2}) + plane.c - referenceZ;
        writingPlan.(names{3}) = writingPlan.(names{3}) + compensation;
    end
end
end
