function trajectory = lw_generate_frame_trajectory(countX, countY, pitchX, pitchY, powerPercent)
%LW_GENERATE_FRAME_TRAJECTORY Build the outer ring of an MxN point grid.

if countX < 1 || countY < 1
    error('Frame point counts must be positive integers.');
end
if pitchX <= 0 || pitchY <= 0
    error('Frame pitches must be positive.');
end
powerPercent = validatePowerPercent(powerPercent, 'Frame power');

xCoords = (0:countX-1)' * pitchX;
yCoords = (0:countY-1)' * pitchY;

if countX == 1 && countY == 1
    coords = [0, 0];
elseif countY == 1
    coords = [xCoords, zeros(countX, 1)];
elseif countX == 1
    coords = [zeros(countY, 1), yCoords];
else
    bottom = [xCoords, zeros(countX, 1)];
    right = [repmat(xCoords(end), countY - 1, 1), yCoords(2:end)];
    top = [flipud(xCoords(1:end-1)), repmat(yCoords(end), countX - 1, 1)];
    left = [zeros(countY - 2, 1), flipud(yCoords(2:end-1))];
    coords = [bottom; right; top; left];
end

z = zeros(size(coords, 1), 1);
meta = struct( ...
    'countX', countX, ...
    'countY', countY, ...
    'pitchX', pitchX, ...
    'pitchY', pitchY, ...
    'powerSource', "plan", ...
    'shape', "frame");
trajectory = lw_make_trajectory(coords(:, 1), coords(:, 2), z, ...
    powerPercent, "frame", "point+stream", meta);
end
