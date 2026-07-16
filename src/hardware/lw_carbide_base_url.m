function baseUrl = lw_carbide_base_url(config)
%LW_CARBIDE_BASE_URL Build the Carbide REST API base URL.

carbideConfig = localCarbideConfig(config);

if isfield(carbideConfig, 'baseUrl') && strlength(string(carbideConfig.baseUrl)) > 0
    baseUrl = char(carbideConfig.baseUrl);
else
    baseUrl = sprintf('http://%s:%d/v1/', char(string(carbideConfig.ip)), double(carbideConfig.port));
end

if ~endsWith(string(baseUrl), "/")
    baseUrl = [baseUrl, '/'];
end
end

function carbideConfig = localCarbideConfig(config)
if isfield(config, 'carbide')
    carbideConfig = config.carbide;
else
    carbideConfig = config;
end

if ~isfield(carbideConfig, 'ip')
    carbideConfig.ip = "192.168.11.251";
end
if ~isfield(carbideConfig, 'port')
    carbideConfig.port = 20010;
end
end
