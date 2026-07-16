function powerSource = trajectoryPowerSource(traj)
powerSource = "file";
if ~isfield(traj, 'meta') || ~isstruct(traj.meta)
    return;
end
if ~isfield(traj.meta, 'powerSource')
    return;
end

candidate = string(traj.meta.powerSource);
if candidate == "fixed"
    candidate = "plan";
end
if any(candidate == ["plan", "file"])
    powerSource = candidate;
end
end
