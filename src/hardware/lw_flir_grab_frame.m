function [flir, frame, info, wasStopped] = lw_flir_grab_frame(flir, timeoutMs, options)
%LW_FLIR_GRAB_FRAME Grab one frame from an active FLIR acquisition.

if nargin < 2 || isempty(timeoutMs)
    timeoutMs = 1500;
end
if nargin < 3 || isempty(options)
    options = struct();
end
if ~isfield(options, 'shouldStopFcn')
    options.shouldStopFcn = [];
end
if ~isfield(options, 'yieldFcn')
    options.yieldFcn = [];
end
if ~isfield(options, 'pollTimeoutMs') || isempty(options.pollTimeoutMs)
    options.pollTimeoutMs = 100;
end
if ~lw_flir_is_connected(flir)
    error('FLIR camera is not connected.');
end
if ~isfield(flir, 'isAcquiring') || ~logical(flir.isAcquiring)
    error('FLIR acquisition is not running.');
end

image = [];
frame = [];
info = struct();
wasStopped = false;
flir.isGrabbing = true;
try
    if isempty(options.shouldStopFcn) && isempty(options.yieldFcn)
        image = flir.cam.GetNextImage(uint64(timeoutMs));
    else
        [image, wasStopped] = getNextImageWithStopPolling();
        if wasStopped
            flir.isGrabbing = false;
            return;
        end
    end

    if logical(image.IsIncomplete)
        statusText = char(image.GetImageStatusDescription(image.ImageStatus));
        error('Incomplete image: %s', statusText);
    end

    [frame, info] = lw_flir_image_to_frame(image);
    if isfield(flir, 'currentRoi') && isstruct(flir.currentRoi) && isfield(flir.currentRoi, 'Name')
        info.RoiName = string(flir.currentRoi.Name);
        if isfield(flir.currentRoi, 'OffsetX')
            info.OffsetX = double(flir.currentRoi.OffsetX);
        end
        if isfield(flir.currentRoi, 'OffsetY')
            info.OffsetY = double(flir.currentRoi.OffsetY);
        end
        if isfield(flir.currentRoi, 'SensorWidth')
            info.SensorWidth = double(flir.currentRoi.SensorWidth);
        end
        if isfield(flir.currentRoi, 'SensorHeight')
            info.SensorHeight = double(flir.currentRoi.SensorHeight);
        end
    end
    info.CapturedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    flir.lastFrame = frame;
    flir.lastFrameInfo = info;
catch ME
    if ~isempty(image)
        try
            image.Release();
        catch
        end
    end
    flir.isGrabbing = false;
    rethrow(ME);
end

try
    image.Release();
catch
end
flir.isGrabbing = false;

    function [imageHandle, stopped] = getNextImageWithStopPolling()
        imageHandle = [];
        stopped = false;
        timerStart = tic;
        timeoutMsValue = max(1, double(timeoutMs));
        pollTimeoutMs = max(1, min(double(options.pollTimeoutMs), timeoutMsValue));

        while true
            if shouldStop()
                stopped = true;
                return;
            end
            yieldToUi();
            if shouldStop()
                stopped = true;
                return;
            end

            elapsedMs = 1000 * toc(timerStart);
            remainingMs = timeoutMsValue - elapsedMs;
            if remainingMs <= 0
                error('lw:FlirGrabTimeout', 'Timed out waiting for FLIR frame after %.0f ms.', timeoutMsValue);
            end

            thisTimeoutMs = uint64(max(1, min(pollTimeoutMs, remainingMs)));
            try
                imageHandle = flir.cam.GetNextImage(thisTimeoutMs);
                return;
            catch ME
                if isGrabTimeoutError(ME) && 1000 * toc(timerStart) < timeoutMsValue
                    continue;
                end
                rethrow(ME);
            end
        end
    end

    function tf = shouldStop()
        tf = false;
        if isempty(options.shouldStopFcn)
            return;
        end
        try
            tf = logical(options.shouldStopFcn());
        catch
            tf = false;
        end
    end

    function yieldToUi()
        if isempty(options.yieldFcn)
            return;
        end
        try
            options.yieldFcn();
        catch
        end
    end
end

function tf = isGrabTimeoutError(err)
message = lower(string(err.message));
tf = contains(message, "timeout") || contains(message, "timed out") || ...
    contains(message, "timedout") || contains(message, "-1011");
end
