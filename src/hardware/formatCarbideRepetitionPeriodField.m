function textValue = formatCarbideRepetitionPeriodField(source)
periodUs = carbideRepetitionPeriodMicroseconds(source);
if isfinite(periodUs)
    textValue = formatCompactNumberLocal(periodUs);
else
    textValue = '-';
end
end
