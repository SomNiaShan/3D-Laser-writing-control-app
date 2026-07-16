function filePath = slm_pattern_path(name, config)
%SLM_PATTERN_PATH Build the .mat file path for a saved pattern.

if nargin < 2
    config = slm_config();
end

filePath = fullfile(slm_pattern_dir(config), [slm_sanitize_pattern_name(name), '.mat']);
end
