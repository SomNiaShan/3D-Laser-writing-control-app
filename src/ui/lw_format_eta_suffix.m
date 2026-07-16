function suffix = lw_format_eta_suffix(startTic, baselineUnits, completedUnits, totalUnits)
%LW_FORMAT_ETA_SUFFIX Format an ETA suffix for run and imaging progress text.

suffix = "";
if isempty(startTic) || totalUnits <= 0
    return;
end

completedUnits = max(0, min(double(completedUnits), double(totalUnits)));
baselineUnits = max(0, min(double(baselineUnits), completedUnits));
remainingUnits = double(totalUnits) - completedUnits;
if remainingUnits <= 1e-9
    return;
end

elapsedSeconds = toc(startTic);
unitsSinceStart = completedUnits - baselineUnits;
if elapsedSeconds < 1 || unitsSinceStart < 1
    suffix = " | ETA estimating...";
    return;
end

etaSeconds = elapsedSeconds * remainingUnits / unitsSinceStart;
if ~isfinite(etaSeconds) || etaSeconds < 0
    suffix = " | ETA estimating...";
    return;
end

suffix = " | ETA " + string(formatEtaDuration(etaSeconds));
end

function textValue = formatEtaDuration(secondsValue)
secondsValue = max(1, round(double(secondsValue)));
if secondsValue < 60
    textValue = sprintf('%d s', secondsValue);
    return;
end

minutesValue = floor(secondsValue / 60);
secondsRemainder = mod(secondsValue, 60);
if secondsValue < 3600
    if minutesValue < 10 && secondsRemainder > 0
        textValue = sprintf('%d min %02d s', minutesValue, secondsRemainder);
    else
        textValue = sprintf('%d min', minutesValue);
    end
    return;
end

hoursValue = floor(secondsValue / 3600);
minutesRemainder = floor(mod(secondsValue, 3600) / 60);
textValue = sprintf('%d h %02d min', hoursValue, minutesRemainder);
end
