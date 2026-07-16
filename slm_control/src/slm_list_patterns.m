function patternNames = slm_list_patterns(config)
%SLM_LIST_PATTERNS List saved SLM pattern names.

if nargin < 1
    config = slm_config();
end

files = dir(fullfile(slm_pattern_dir(config), '*.mat'));
patternNames = strings(numel(files), 1);

for index = 1:numel(files)
    [~, patternNames(index)] = fileparts(files(index).name);
end
end
