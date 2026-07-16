function prefix = lw_imaging_prefix_with_slm_token(userPrefix, slmToken)
%LW_IMAGING_PREFIX_WITH_SLM_TOKEN Append the SLM token to an imaging prefix.

prefix = char(string(userPrefix));
if strlength(string(slmToken)) > 0
    prefix = sprintf('%s_%s', prefix, char(slmToken));
end
prefix = sanitizeFileComponent(prefix, 'beam_stack');
end

function textValue = sanitizeFileComponent(rawValue, fallback)
textValue = char(strtrim(string(rawValue)));
if isempty(textValue)
    textValue = fallback;
end
textValue = regexprep(textValue, '[^\w\.=-]+', '_');
textValue = regexprep(textValue, '_+', '_');
textValue = regexprep(textValue, '^_+|_+$', '');
if isempty(textValue)
    textValue = fallback;
end
end
