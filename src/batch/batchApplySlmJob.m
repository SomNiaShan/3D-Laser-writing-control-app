function [snapshot, pattern, adjustedPattern] = batchApplySlmJob(job, ctx, showOnSlm, isOpen, isConnected)
if nargin < 3
    showOnSlm = false;
end
if nargin < 4
    isOpen = true;
end
if nargin < 5
    isConnected = false;
end

pattern = slm_generate_drill_beam_phase(ctx, job.options);
adjustedPattern = applyBatchGlobalAdjustments(pattern, job.globalAdjustments, ctx);
if showOnSlm
    slm_show_pattern(ctx, adjustedPattern);
end

snapshot = struct();
snapshot.source = "laser-writing-batch-slm";
snapshot.updatedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
snapshot.isOpen = logical(isOpen);
snapshot.isConnected = logical(isConnected);
snapshot.currentOnSlm = string(adjustedPattern.name);
snapshot.options = job.options;
snapshot.globalAdjustments = job.globalAdjustments;
snapshot.currentPatternName = string(pattern.name);
snapshot.currentAdjustedPatternName = string(adjustedPattern.name);
end
