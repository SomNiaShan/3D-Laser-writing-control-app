function plane = lw_leveling_plane_from_marks(marks)
%LW_LEVELING_PLANE_FROM_MARKS Fit a 3-point plane z = a*x + b*y + c.

mark0 = marks.mark0;
mark1 = marks.mark1;
mark2 = marks.mark2;

if isempty(mark0) || isempty(mark1) || isempty(mark2)
    error('Point A, Point B, and Point C are all required for surface leveling.');
end

points = [mark0; mark1; mark2];
if size(points, 2) ~= 3 || any(~isfinite(points(:)))
    error('Surface leveling points must be finite X/Y/Z coordinates.');
end

fitMatrix = [points(:, 1), points(:, 2), ones(3, 1)];
if rank(fitMatrix) < 3
    error('Point A, Point B, and Point C must not be collinear.');
end

coefficients = fitMatrix \ points(:, 3);

plane = struct( ...
    'a', coefficients(1), ...
    'b', coefficients(2), ...
    'c', coefficients(3), ...
    'anchor', mark0, ...
    'points', points, ...
    'slopeXUmPerMm', coefficients(1) * 1e3, ...
    'slopeYUmPerMm', coefficients(2) * 1e3);
