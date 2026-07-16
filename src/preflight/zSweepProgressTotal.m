function count = zSweepProgressTotal(sweep)
switch string(sweep.exposureDirection)
    case "Front -> Back"
        count = 1 + sweep.repeatCount + max(sweep.repeatCount - 1, 0);
    otherwise
        count = 1 + 2 * sweep.repeatCount;
end
end
