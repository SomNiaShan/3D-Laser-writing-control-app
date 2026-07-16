function setVisibility(components, shouldShow)
if nargin < 2
    shouldShow = true;
end

if iscell(components)
    for k = 1:numel(components)
        setVisibility(components{k}, shouldShow);
    end
    return;
end

if numel(components) > 1
    for k = 1:numel(components)
        setVisibility(components(k), shouldShow);
    end
    return;
end

if shouldShow
    components.Visible = 'on';
else
    components.Visible = 'off';
end
end
