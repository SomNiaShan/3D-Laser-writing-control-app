function stats = lw_imaging_frame_exposure_stats(frame, info)
%LW_IMAGING_FRAME_EXPOSURE_STATS Measure saturation and scale for one frame.

values = double(frame(:));
pixelCount = numel(values);
fullScale = imagingFrameFullScale(frame, info);
if pixelCount == 0
    maxIntensity = NaN;
    saturatedPixels = 0;
else
    maxIntensity = max(values);
    saturatedPixels = nnz(values >= fullScale);
end

stats = struct( ...
    'maxIntensity', maxIntensity, ...
    'fullScale', fullScale, ...
    'pixelCount', pixelCount, ...
    'saturatedPixels', saturatedPixels, ...
    'saturatedFraction', saturatedPixels / max(pixelCount, 1), ...
    'isSaturated', saturatedPixels > 0);
end

function fullScale = imagingFrameFullScale(frame, info)
bitDepth = NaN;
if isstruct(info) && isfield(info, 'PixelFormat') && ~isempty(info.PixelFormat)
    bitDepth = imagingPixelFormatBitDepth(info.PixelFormat);
end
if (~isfinite(bitDepth) || bitDepth <= 0) && isstruct(info) && ...
        isfield(info, 'BitsPerPixel') && ~isempty(info.BitsPerPixel)
    bitDepth = double(info.BitsPerPixel);
    if isfield(info, 'Channels') && double(info.Channels) > 1
        bitDepth = bitDepth / double(info.Channels);
    end
end

classBitDepth = imagingFrameClassBitDepth(frame);
if isfinite(bitDepth) && bitDepth > 0
    if isfinite(classBitDepth)
        bitDepth = min(bitDepth, classBitDepth);
    end
    fullScale = 2.^round(bitDepth) - 1;
    return;
end

if isinteger(frame)
    fullScale = double(intmax(class(frame)));
else
    values = double(frame(:));
    if isempty(values) || max(values) <= 1
        fullScale = 1;
    else
        fullScale = max(values);
    end
end
end

function bitDepth = imagingPixelFormatBitDepth(pixelFormat)
bitDepth = NaN;
tokens = regexp(char(string(pixelFormat)), '(\d+)', 'tokens', 'once');
if ~isempty(tokens)
    bitDepth = str2double(tokens{1});
end
end

function bitDepth = imagingFrameClassBitDepth(frame)
switch class(frame)
    case 'uint8'
        bitDepth = 8;
    case 'uint16'
        bitDepth = 16;
    case 'uint32'
        bitDepth = 32;
    case 'uint64'
        bitDepth = 64;
    case 'int8'
        bitDepth = 7;
    case 'int16'
        bitDepth = 15;
    case 'int32'
        bitDepth = 31;
    case 'int64'
        bitDepth = 63;
    case 'logical'
        bitDepth = 1;
    otherwise
        bitDepth = NaN;
end
end
