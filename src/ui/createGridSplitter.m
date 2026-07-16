function splitter = createGridSplitter(parentGrid, rowSpec, columnSpec, dimension, lowTrack, highTrack)
splitter = uipanel(parentGrid, ...
    'BorderType', 'none', ...
    'BackgroundColor', [0.72, 0.72, 0.72], ...
    'ButtonDownFcn', @(~, ~) startGridResize(parentGrid, dimension, lowTrack, highTrack));
splitter.Tag = 'GridResizeSplitter';
if isprop(splitter, 'Tooltip')
    splitter.Tooltip = 'Drag to resize adjacent panels';
end
splitter.Layout.Row = rowSpec;
splitter.Layout.Column = columnSpec;
end
