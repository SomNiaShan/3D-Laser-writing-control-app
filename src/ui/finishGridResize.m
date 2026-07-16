function finishGridResize(figHandle, ~)
if isempty(figHandle) || ~isValidUiHandle(figHandle) || ...
        ~isappdata(figHandle, 'LaserWritingGridResizeDrag')
    return;
end

resizeDrag = getappdata(figHandle, 'LaserWritingGridResizeDrag');
rmappdata(figHandle, 'LaserWritingGridResizeDrag');

if isValidUiHandle(figHandle)
    figHandle.WindowButtonMotionFcn = resizeDrag.PreviousMotionFcn;
    figHandle.WindowButtonUpFcn = resizeDrag.PreviousUpFcn;
    try
        figHandle.Pointer = resizeDrag.PreviousPointer;
    catch
    end
end
end
