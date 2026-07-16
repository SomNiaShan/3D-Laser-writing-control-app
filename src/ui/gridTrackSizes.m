function trackSizes = gridTrackSizes(gridHandle, dimension)
if string(dimension) == "column"
    trackSizes = gridHandle.ColumnWidth;
else
    trackSizes = gridHandle.RowHeight;
end
end
