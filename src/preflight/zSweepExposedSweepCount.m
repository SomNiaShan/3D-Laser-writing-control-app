function count = zSweepExposedSweepCount(sweep)
switch string(sweep.exposureDirection)
    case "Both Directions"
        count = 2 * sweep.repeatCount;
    otherwise
        count = sweep.repeatCount;
end
end
