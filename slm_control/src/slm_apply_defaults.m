function config = slm_apply_defaults(config, defaults)
%SLM_APPLY_DEFAULTS Fill missing top-level fields in a config struct.

if nargin < 1 || isempty(config)
    config = struct();
end
if nargin < 2 || isempty(defaults)
    defaults = struct();
end

names = fieldnames(defaults);
for index = 1:numel(names)
    name = names{index};
    if ~isfield(config, name) || isempty(config.(name))
        config.(name) = defaults.(name);
    end
end
end
