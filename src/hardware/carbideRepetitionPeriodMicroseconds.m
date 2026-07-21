function periodUs = carbideRepetitionPeriodMicroseconds(source)
frequencyKHz = carbideNumericField(source, [ ...
    "ActualOutputFrequency", "ActualFrequency", "OutputFrequency"]);

periodUs = NaN;
if isreal(frequencyKHz) && isfinite(frequencyKHz) && frequencyKHz > 0
    candidatePeriodUs = 1000 / frequencyKHz;
    if isfinite(candidatePeriodUs)
        periodUs = candidatePeriodUs;
    end
end
end
