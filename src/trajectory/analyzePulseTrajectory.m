function pulseAnalysis = analyzePulseTrajectory(traj, pulseSpeedMmPerSecond, pulseWidthUs, maxTriggerRateHz)
pulseAnalysis = struct();
pulseAnalysis.pulseTimesSeconds = zeros(numel(traj.x), 1);
pulseAnalysis.requiredTriggerRateHz = 0;
pulseAnalysis.minIntervalSeconds = inf;

if numel(traj.x) < 2
    return;
end

dx = diff(traj.x(:));
dy = diff(traj.y(:));
dz = diff(traj.z(:));
segmentLengths = sqrt(dx .^ 2 + dy .^ 2 + dz .^ 2);

repeatedIndex = find(segmentLengths <= 0, 1, 'first');
if ~isempty(repeatedIndex)
    error('Stream Mode cancelled: points %d and %d are identical. Remove repeated points first.', ...
        repeatedIndex, repeatedIndex + 1);
end

intervalSeconds = segmentLengths ./ pulseSpeedMmPerSecond;
pulseAnalysis.minIntervalSeconds = min(intervalSeconds);
pulseAnalysis.requiredTriggerRateHz = 1 / pulseAnalysis.minIntervalSeconds;
pulseAnalysis.pulseTimesSeconds(2:end) = cumsum(intervalSeconds);

if pulseAnalysis.requiredTriggerRateHz > maxTriggerRateHz
    error(['Stream Mode cancelled: required trigger rate %.3f Hz exceeds the configured maximum %.3f Hz. ', ...
        'Reduce Stream Speed or increase the point spacing.'], ...
        pulseAnalysis.requiredTriggerRateHz, maxTriggerRateHz);
end

pulseWidthSeconds = pulseWidthUs * 1e-6;
if pulseWidthSeconds >= pulseAnalysis.minIntervalSeconds
    error('Stream Mode cancelled: TTL Gate Width %.3f us must stay below the shortest point interval %.3f us.', ...
        pulseWidthUs, pulseAnalysis.minIntervalSeconds * 1e6);
end
end
