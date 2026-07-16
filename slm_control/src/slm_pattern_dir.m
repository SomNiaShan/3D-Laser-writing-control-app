function patternDir = slm_pattern_dir(config)
%SLM_PATTERN_DIR Return the directory used for saved SLM patterns.

if nargin < 1 || isempty(config)
    config = slm_config();
end

if isfield(config, 'patternDir') && ~isempty(config.patternDir)
    patternDir = config.patternDir;
else
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    patternDir = fullfile(repoRoot, 'patterns');
end

if exist(patternDir, 'dir') ~= 7
    mkdir(patternDir);
end
end
