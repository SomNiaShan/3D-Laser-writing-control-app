function response = lw_carbide_request(config, method, endpoint, payload)
%LW_CARBIDE_REQUEST Small REST wrapper for Carbide User App endpoints.

if nargin < 4
    payload = [];
end

carbideConfig = localCarbideConfig(config);
baseUrl = lw_carbide_base_url(carbideConfig);
endpoint = regexprep(strtrim(char(string(endpoint))), '^/+', '');
url = [baseUrl, endpoint];
timeoutSeconds = localTimeoutSeconds(carbideConfig);
method = upper(string(method));

try
    switch method
        case "GET"
            options = weboptions('Timeout', timeoutSeconds);
            response = webread(url, options);
        case {"PUT", "POST"}
            options = weboptions( ...
                'Timeout', timeoutSeconds, ...
                'RequestMethod', lower(char(method)), ...
                'MediaType', 'application/json');
            response = webwrite(url, localPayloadText(payload), options);
        otherwise
            error('Unsupported Carbide REST method: %s', char(method));
    end
catch ME
    error('lw:CarbideRequestFailed', ...
        'Carbide %s /%s failed: %s', char(method), endpoint, ME.message);
end

response = localDecodeJson(response);
end

function carbideConfig = localCarbideConfig(config)
if isfield(config, 'carbide')
    carbideConfig = config.carbide;
else
    carbideConfig = config;
end
end

function timeoutSeconds = localTimeoutSeconds(carbideConfig)
timeoutSeconds = 2;
if isfield(carbideConfig, 'timeoutSeconds') && isfinite(double(carbideConfig.timeoutSeconds))
    timeoutSeconds = double(carbideConfig.timeoutSeconds);
end
end

function payloadText = localPayloadText(payload)
if isempty(payload) && ~isnumeric(payload)
    payloadText = '';
else
    payloadText = jsonencode(payload);
end
end

function response = localDecodeJson(response)
if ischar(response) || isstring(response)
    responseText = char(response);
    if ~isempty(strtrim(responseText))
        try
            response = jsondecode(responseText);
        catch
        end
    end
end
end
