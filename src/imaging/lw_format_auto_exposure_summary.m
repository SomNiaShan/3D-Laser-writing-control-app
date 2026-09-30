function textValue = lw_format_auto_exposure_summary(options)
%LW_FORMAT_AUTO_EXPOSURE_SUMMARY Describe auto exposure scout settings for preflight text.

textValue = "Off";
if ~isstruct(options) || ~isfield(options, 'enabled') || ~logical(options.enabled)
    return;
end

sampleCount = 0;
if isfield(options, 'sampleCount')
    sampleCount = options.sampleCount;
end
safetyFactor = 0.8;
if isfield(options, 'safetyFactor')
    safetyFactor = double(options.safetyFactor);
end

detail = string(sprintf('%d Z samples, %.0f%% no-clip target', sampleCount, 100 * safetyFactor));
if safetyFactor > 1
    detail = detail + "; above 100% the brightest pixels will saturate";
end
textValue = "On (" + detail + ")";
end
