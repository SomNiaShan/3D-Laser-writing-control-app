function adjustmentNames = slm_list_global_adjustments(config)
%SLM_LIST_GLOBAL_ADJUSTMENTS List saved global adjustment preset names.

if nargin < 1
    config = slm_config();
end

files = dir(fullfile(slm_global_adjustment_dir(config), '*.mat'));
adjustmentNames = strings(numel(files), 1);

for index = 1:numel(files)
    [~, adjustmentNames(index)] = fileparts(files(index).name);
end
end
