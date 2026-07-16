function color = lampColor(isActive, onColor, offColor)
if nargin < 2
    onColor = [0.2, 0.7, 0.2];
end
if nargin < 3
    offColor = [0.85, 0.2, 0.2];
end

if isActive
    color = onColor;
else
    color = offColor;
end
end
