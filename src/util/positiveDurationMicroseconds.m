function secondsValue = positiveDurationMicroseconds(rawValue, label)
microsecondsValue = double(rawValue);
if ~isscalar(microsecondsValue) || ~isfinite(microsecondsValue) || microsecondsValue <= 0
    error('%s must be a positive duration in us.', label);
end
secondsValue = microsecondsValue * 1e-6;
end
