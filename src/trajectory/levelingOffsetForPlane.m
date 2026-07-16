function offsets = levelingOffsetForPlane(plane, xValues, yValues, referencePoint)
xValues = xValues(:);
yValues = yValues(:);
if nargin < 4 || isempty(referencePoint)
    referenceXY = plane.anchor(1:2);
elseif isstruct(referencePoint)
    referenceXY = [referencePoint.x, referencePoint.y];
else
    referenceXY = referencePoint(1:2);
end
referenceZ = plane.a * referenceXY(1) + plane.b * referenceXY(2) + plane.c;
offsets = plane.a * xValues + plane.b * yValues + plane.c - referenceZ;
end
