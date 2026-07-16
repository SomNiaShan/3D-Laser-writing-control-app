function onGridResizeDrag(figHandle, ~)
if isempty(figHandle) || ~isValidUiHandle(figHandle) || ...
        ~isappdata(figHandle, 'LaserWritingGridResizeDrag')
    finishGridResize(figHandle);
    return;
end

resizeDrag = getappdata(figHandle, 'LaserWritingGridResizeDrag');
if isempty(resizeDrag) || ~isValidUiHandle(resizeDrag.Grid)
    finishGridResize(figHandle);
    return;
end

point = figHandle.CurrentPoint;
pixelsPerWeight = trackPixelsPerFlexUnit(resizeDrag.Grid, resizeDrag.Dimension);
if ~isfinite(pixelsPerWeight) || pixelsPerWeight <= 0
    return;
end

if resizeDrag.Dimension == "column"
    deltaPixels = point(1) - resizeDrag.StartPoint(1);
else
    deltaPixels = resizeDrag.StartPoint(2) - point(2);
end

pairWeight = resizeDrag.StartLowWeight + resizeDrag.StartHighWeight;
minWeight = resizeDrag.MinPixels / pixelsPerWeight;
minWeight = min(minWeight, max(pairWeight / 2 - eps, pairWeight * 0.05));

lowWeight = resizeDrag.StartLowWeight + deltaPixels / pixelsPerWeight;
lowWeight = min(max(lowWeight, minWeight), pairWeight - minWeight);
highWeight = pairWeight - lowWeight;

trackSizes = resizeDrag.StartSizes;
trackSizes{resizeDrag.LowTrack} = formatFlexTrack(lowWeight);
trackSizes{resizeDrag.HighTrack} = formatFlexTrack(highWeight);
setGridTrackSizes(resizeDrag.Grid, resizeDrag.Dimension, trackSizes);
drawnow limitrate;
end
