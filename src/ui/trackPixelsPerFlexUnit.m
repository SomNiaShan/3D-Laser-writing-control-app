function pixelsPerWeight = trackPixelsPerFlexUnit(gridHandle, dimension)
trackSizes = gridTrackSizes(gridHandle, dimension);
padding = gridHandle.Padding;

if string(dimension) == "column"
    availablePixels = gridHandle.Position(3) - padding(1) - padding(3);
    spacing = gridHandle.ColumnSpacing;
else
    availablePixels = gridHandle.Position(4) - padding(2) - padding(4);
    spacing = gridHandle.RowSpacing;
end

availablePixels = availablePixels - spacing * max(0, numel(trackSizes) - 1);
fixedPixels = 0;
totalWeight = 0;
for i = 1:numel(trackSizes)
    weight = trackFlexValue(trackSizes{i});
    if isfinite(weight)
        totalWeight = totalWeight + weight;
    elseif isnumeric(trackSizes{i})
        fixedPixels = fixedPixels + trackSizes{i};
    end
end

pixelsPerWeight = max(1, (availablePixels - fixedPixels) / max(totalWeight, eps));
end
