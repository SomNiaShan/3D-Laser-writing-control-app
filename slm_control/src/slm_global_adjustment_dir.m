function adjustmentDir = slm_global_adjustment_dir(config)
%SLM_GLOBAL_ADJUSTMENT_DIR Return the directory used for saved global presets.

if nargin < 1 || isempty(config)
    config = slm_config();
end

if isfield(config, 'globalAdjustmentDir') && ~isempty(config.globalAdjustmentDir)
    adjustmentDir = config.globalAdjustmentDir;
else
    adjustmentDir = fullfile(slm_pattern_dir(config), 'global_adjustments');
end

if exist(adjustmentDir, 'dir') ~= 7
    mkdir(adjustmentDir);
end
end
