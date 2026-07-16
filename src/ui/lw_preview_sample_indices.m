function indices = lw_preview_sample_indices(pointCount, maxPoints)
%LW_PREVIEW_SAMPLE_INDICES Return a bounded set of point indices for previews.

pointCount = max(0, round(double(pointCount)));
maxPoints = max(1, round(double(maxPoints)));
if pointCount <= maxPoints
    indices = (1:pointCount).';
    return;
end

indices = unique(round(linspace(1, pointCount, maxPoints)));
indices = indices(:);
end
