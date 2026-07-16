function trajectory = lw_make_trajectory(x, y, z, power, sourceType, modeSupport, meta)
%LW_MAKE_TRAJECTORY Create the standard trajectory structure.

if nargin < 7 || isempty(meta)
    meta = struct();
end

x = x(:);
y = y(:);
z = z(:);

if ~(numel(x) == numel(y) && numel(y) == numel(z))
    error('X, Y, and Z must have the same length.');
end

if nargin < 4 || isempty(power)
    power = nan(size(x));
else
    power = power(:);
    if ~(isscalar(power) || numel(power) == numel(x))
        error('Power must be scalar or match the trajectory length.');
    end
    if isscalar(power)
        power = repmat(power, size(x));
    end
end

trajectory = struct();
trajectory.x = x;
trajectory.y = y;
trajectory.z = z;
trajectory.power = power;
trajectory.sourceType = sourceType;
trajectory.modeSupport = modeSupport;
trajectory.meta = meta;
end
