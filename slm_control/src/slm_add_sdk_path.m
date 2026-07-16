function sdkPath = slm_add_sdk_path(config)
%SLM_ADD_SDK_PATH Add HOLOEYE MATLAB SDK folders to the MATLAB path.

if nargin < 1 || isempty(config)
    config = slm_config();
end

sdkPath = '';

if isfield(config, 'sdkPath') && ~isempty(config.sdkPath) && exist(config.sdkPath, 'dir') == 7
    sdkPath = config.sdkPath;
end

if isempty(sdkPath)
    envVarName = 'HEDS_4_1_MATLAB';
    if isfield(config, 'sdkEnvVar') && ~isempty(config.sdkEnvVar)
        envVarName = config.sdkEnvVar;
    end

    envPath = getenv(envVarName);
    if ~isempty(envPath) && exist(envPath, 'dir') == 7
        sdkPath = envPath;
    end
end

if isempty(sdkPath)
    candidates = { ...
        'C:\Program Files\HOLOEYE Photonics\SLM Display SDK (MATLAB) v4.1.0', ...
        'C:\Program Files\HOLOEYE Photonics\SLM Display SDK (MATLAB)' ...
    };

    for index = 1:numel(candidates)
        if exist(candidates{index}, 'dir') == 7
            sdkPath = candidates{index};
            break;
        end
    end
end

if isempty(sdkPath)
    error('SLM:SdkNotFound', ...
        'Could not find the HOLOEYE SLM Display SDK for MATLAB. Update config.sdkPath.');
end

apiPath = fullfile(sdkPath, 'api', 'matlab');
if exist(apiPath, 'dir') ~= 7
    error('SLM:SdkApiNotFound', ...
        'Found SDK path, but the MATLAB API folder is missing: %s', apiPath);
end

sdkFolders = { ...
    fullfile(apiPath, 'hedslibapi_mex'), ...
    fullfile(apiPath, 'slmwindow'), ...
    fullfile(apiPath, 'slmpreview'), ...
    fullfile(apiPath, 'slm'), ...
    fullfile(apiPath, 'sdk'), ...
    apiPath ...
};

for index = 1:numel(sdkFolders)
    if exist(sdkFolders{index}, 'dir') == 7
        addpath(sdkFolders{index});
    end
end
end
