function filePath = slm_save_pattern(pattern, name, config)
%SLM_SAVE_PATTERN Save an SLM pattern struct for later on-demand loading.

if nargin < 1 || ~isstruct(pattern) || ~isfield(pattern, 'phaseData')
    error('SLM:InvalidPattern', 'pattern must be a struct containing phaseData.');
end
if nargin < 2 || isempty(name)
    if isfield(pattern, 'name') && ~isempty(pattern.name)
        name = pattern.name;
    else
        name = 'slm_pattern';
    end
end
if nargin < 3
    config = slm_config();
end

pattern.name = char(name);
pattern.savedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
filePath = slm_pattern_path(name, config);

save(filePath, 'pattern', '-v7.3');
end
