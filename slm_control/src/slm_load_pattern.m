function pattern = slm_load_pattern(name, config)
%SLM_LOAD_PATTERN Load a saved SLM pattern by name or direct file path.

if nargin < 1 || isempty(name)
    error('SLM:MissingPatternName', 'Pattern name or file path is required.');
end
if nargin < 2
    config = slm_config();
end

candidate = char(name);
if exist(candidate, 'file') == 2
    filePath = candidate;
else
    filePath = slm_pattern_path(candidate, config);
end

if exist(filePath, 'file') ~= 2
    error('SLM:PatternNotFound', 'Could not find saved pattern: %s', filePath);
end

loaded = load(filePath, 'pattern');
if ~isfield(loaded, 'pattern') || ~isstruct(loaded.pattern) || ~isfield(loaded.pattern, 'phaseData')
    error('SLM:InvalidPatternFile', 'File does not contain a valid pattern struct: %s', filePath);
end

pattern = loaded.pattern;
pattern.sourceFile = filePath;
end
