function shutterColor = carbideShutterStateColor(shutterText)
lowerText = lower(string(shutterText));
if any(contains(lowerText, ["opening", "closing", "moving", "transition"]))
    shutterColor = [0.95, 0.7, 0.15];
elseif contains(lowerText, "open")
    shutterColor = [0.2, 0.7, 0.2];
elseif contains(lowerText, "closed")
    shutterColor = [0.85, 0.2, 0.2];
else
    shutterColor = [0.5, 0.5, 0.5];
end
end
