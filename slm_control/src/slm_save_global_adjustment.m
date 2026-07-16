function filePath = slm_save_global_adjustment(options, name, config)
%SLM_SAVE_GLOBAL_ADJUSTMENT Save global adjustment options as a reusable preset.

if nargin < 1 || ~isstruct(options)
    error('SLM:InvalidGlobalAdjustment', 'options must be a struct.');
end
if nargin < 2 || isempty(name)
    name = 'global_adjustment';
end
if nargin < 3
    config = slm_config();
end

safeName = slm_sanitize_pattern_name(name);

globalAdjustment = struct();
globalAdjustment.name = safeName;
globalAdjustment.options = options;
globalAdjustment.savedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

filePath = slm_global_adjustment_path(safeName, config);
save(filePath, 'globalAdjustment', '-v7.3');
end
