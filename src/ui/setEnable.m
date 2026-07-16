function setEnable(components, shouldEnable)
if nargin < 2
    shouldEnable = true;
end

if iscell(components)
    for k = 1:numel(components)
        setEnable(components{k}, shouldEnable);
    end
    return;
end

if numel(components) > 1
    for k = 1:numel(components)
        setEnable(components(k), shouldEnable);
    end
    return;
end

if shouldEnable
    components.Enable = 'on';
else
    components.Enable = 'off';
end
end
