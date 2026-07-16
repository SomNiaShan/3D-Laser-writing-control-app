function figHandle = uiFigureAncestor(handleValue)
figHandle = [];
try
    figHandle = ancestor(handleValue, 'figure');
catch
end
end
