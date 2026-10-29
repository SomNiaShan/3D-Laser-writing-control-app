function roi = lw_flir_normalize_roi(request, limits)
%LW_FLIR_NORMALIZE_ROI Snap a requested ROI to the camera size and step rules.
%   REQUEST holds OffsetX, OffsetY, Width, and Height in full-sensor pixels.
%   LIMITS comes from lw_flir_read_roi_limits. The result stays inside the
%   sensor and lands on the camera Width/Height/Offset increments.

[offsetX, width] = normalizeAxis(request.OffsetX, request.Width, limits.SensorWidth, ...
    limits.WidthMin, limits.WidthIncrement, limits.OffsetXIncrement, 'X');
[offsetY, height] = normalizeAxis(request.OffsetY, request.Height, limits.SensorHeight, ...
    limits.HeightMin, limits.HeightIncrement, limits.OffsetYIncrement, 'Y');

roi = struct( ...
    'OffsetX', offsetX, ...
    'OffsetY', offsetY, ...
    'Width', width, ...
    'Height', height);
end

function [offset, extent] = normalizeAxis(offset, extent, sensorExtent, minExtent, extentStep, offsetStep, axisName)
offset = double(offset);
extent = double(extent);
if ~isscalar(offset) || ~isfinite(offset) || ~isscalar(extent) || ~isfinite(extent) || extent <= 0
    error('lw:flir:InvalidRoi', ...
        'FLIR ROI %s offset and size must be finite numbers with a positive size.', axisName);
end

sensorExtent = round(double(sensorExtent));
minExtent = max(1, round(double(minExtent)));
extentStep = max(1, round(double(extentStep)));
offsetStep = max(1, round(double(offsetStep)));
if sensorExtent < minExtent
    error('lw:flir:InvalidRoi', 'FLIR sensor %s size %d is smaller than the minimum ROI size %d.', ...
        axisName, sensorExtent, minExtent);
end

maxExtent = minExtent + floor((sensorExtent - minExtent) / extentStep) * extentStep;
extent = minExtent + round((extent - minExtent) / extentStep) * extentStep;
extent = min(max(extent, minExtent), maxExtent);

maxOffset = floor((sensorExtent - extent) / offsetStep) * offsetStep;
offset = round(offset / offsetStep) * offsetStep;
offset = min(max(offset, 0), maxOffset);
end
