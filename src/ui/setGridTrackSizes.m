function setGridTrackSizes(gridHandle, dimension, trackSizes)
if string(dimension) == "column"
    gridHandle.ColumnWidth = trackSizes;
else
    gridHandle.RowHeight = trackSizes;
end
end
