function isBusy = lw_axis_is_busy(axisHandle, options)
%LW_AXIS_IS_BUSY Query axis busy state with short retry handling.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isfield(options, 'maxRetries') || isempty(options.maxRetries)
    options.maxRetries = 3;
end
if ~isfield(options, 'retryDelaySeconds') || isempty(options.retryDelaySeconds)
    options.retryDelaySeconds = 0.05;
end

maxRetries = max(0, round(double(options.maxRetries)));
retryDelaySeconds = max(0, double(options.retryDelaySeconds));
retryCount = 0;

while true
    try
        isBusy = logical(axisHandle.isBusy());
        return;
    catch ME
        if retryCount >= maxRetries || ~localIsRequestTimeout(ME)
            rethrow(ME);
        end

        retryCount = retryCount + 1;
        pause(retryDelaySeconds);
    end
end
end

function tf = localIsRequestTimeout(err)
message = string(err.message);
tf = contains(message, "RequestTimeoutException") || ...
    contains(message, "Device has not responded in given timeout");
if tf
    return;
end

try
    causes = err.cause;
catch
    causes = {};
end

for i = 1:numel(causes)
    if localIsRequestTimeout(causes{i})
        tf = true;
        return;
    end
end
end
