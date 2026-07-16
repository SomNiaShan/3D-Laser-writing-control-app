function safeName = slm_sanitize_pattern_name(name)
%SLM_SANITIZE_PATTERN_NAME Convert a pattern name into a safe file token.

if nargin < 1 || isempty(name)
    error('SLM:MissingPatternName', 'Pattern name is required.');
end

safeName = regexprep(char(name), '[^A-Za-z0-9_\-]', '_');
safeName = regexprep(safeName, '_+', '_');
safeName = strtrim(safeName);

if isempty(safeName)
    error('SLM:InvalidPatternName', 'Pattern name does not contain usable characters.');
end
end
