function labelHandle = createRightLabel(parent, textValue, row, column)
labelHandle = uilabel(parent, 'Text', textValue, 'HorizontalAlignment', 'right');
labelHandle.Layout.Row = row;
labelHandle.Layout.Column = column;
end
