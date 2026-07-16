function filePath = slm_global_adjustment_path(name, config)
%SLM_GLOBAL_ADJUSTMENT_PATH Build the .mat file path for a saved global preset.

if nargin < 2
    config = slm_config();
end

filePath = fullfile(slm_global_adjustment_dir(config), ...
    [slm_sanitize_pattern_name(name), '.mat']);
end
