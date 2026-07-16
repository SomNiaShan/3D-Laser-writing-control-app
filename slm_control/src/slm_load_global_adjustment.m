function globalAdjustment = slm_load_global_adjustment(name, config)
%SLM_LOAD_GLOBAL_ADJUSTMENT Load a saved global adjustment preset.

if nargin < 1 || isempty(name)
    error('SLM:MissingGlobalAdjustmentName', 'Global adjustment name or file path is required.');
end
if nargin < 2
    config = slm_config();
end

candidate = char(name);
if exist(candidate, 'file') == 2
    filePath = candidate;
else
    filePath = slm_global_adjustment_path(candidate, config);
end

if exist(filePath, 'file') ~= 2
    error('SLM:GlobalAdjustmentNotFound', ...
        'Could not find saved global adjustment: %s', filePath);
end

loaded = load(filePath, 'globalAdjustment');
if ~isfield(loaded, 'globalAdjustment') || ~isstruct(loaded.globalAdjustment) || ...
        ~isfield(loaded.globalAdjustment, 'options') || ...
        ~isstruct(loaded.globalAdjustment.options)
    error('SLM:InvalidGlobalAdjustmentFile', ...
        'File does not contain a valid global adjustment preset: %s', filePath);
end

globalAdjustment = loaded.globalAdjustment;
globalAdjustment.sourceFile = filePath;
end
