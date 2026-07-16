function label = markDisplayName(markName)
switch string(markName)
    case "mark0"
        label = "Point A";
    case "mark1"
        label = "Point B";
    case "mark2"
        label = "Point C";
    otherwise
        label = string(markName);
end
end
