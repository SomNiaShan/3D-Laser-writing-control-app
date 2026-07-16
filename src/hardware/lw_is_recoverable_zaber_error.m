function tf = lw_is_recoverable_zaber_error(err)
%LW_IS_RECOVERABLE_ZABER_ERROR True for Zaber link errors worth reconnecting.

message = string(err.message);
tf = contains(message, "ConnectionClosedException") || ...
    contains(message, "Connection has been closed") || ...
    contains(message, "RequestTimeoutException") || ...
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
    if lw_is_recoverable_zaber_error(causes{i})
        tf = true;
        return;
    end
end
end
