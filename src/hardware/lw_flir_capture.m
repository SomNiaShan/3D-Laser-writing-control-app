function [flir, frame, info, wasStopped] = lw_flir_capture(flir, options)
%LW_FLIR_CAPTURE Capture one frame, starting/stopping acquisition if needed.

if nargin < 2 || isempty(options)
    options = struct();
end
if ~isfield(options, 'timeoutMs') || isempty(options.timeoutMs)
    options.timeoutMs = 1500;
end
if ~isfield(options, 'useNativeResolution') || isempty(options.useNativeResolution)
    options.useNativeResolution = true;
end
if ~isfield(options, 'captureRegion') || isempty(options.captureRegion)
    options.captureRegion = "full";
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

temporaryAcquisition = ~isfield(flir, 'isAcquiring') || ~logical(flir.isAcquiring);
try
    if logical(options.useNativeResolution) && temporaryAcquisition
        flir = lw_flir_set_capture_region(flir, options.captureRegion);
    end
    if temporaryAcquisition
        flir = lw_flir_start_acquisition(flir);
    end
    grabOptions = struct( ...
        'shouldStopFcn', options.shouldStopFcn, ...
        'yieldFcn', options.yieldFcn, ...
        'pollTimeoutMs', options.pollTimeoutMs);
    [flir, frame, info, wasStopped] = lw_flir_grab_frame(flir, options.timeoutMs, grabOptions);
catch ME
    if temporaryAcquisition
        try
            lw_flir_stop_acquisition(flir);
        catch
        end
    end
    rethrow(ME);
end

if temporaryAcquisition
    flir = lw_flir_stop_acquisition(flir);
end
end
