function enableScrolling(layoutHandle)
if isprop(layoutHandle, 'Scrollable')
    layoutHandle.Scrollable = 'on';
end
end
