function tf = supportsMode(traj, modeName)
tf = contains(lower(char(traj.modeSupport)), lower(modeName));
end
