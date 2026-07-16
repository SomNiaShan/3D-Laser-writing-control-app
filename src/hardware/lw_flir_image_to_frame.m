function [frame, info] = lw_flir_image_to_frame(image)
%LW_FLIR_IMAGE_TO_FRAME Convert a Spinnaker image object to a MATLAB array.

width = double(image.Width);
height = double(image.Height);
bitsPerPixel = double(image.BitsPerPixel);
channels = double(image.NumChannels);
pixelFormat = char(image.PixelFormatName);
raw = uint8(image.ManagedData);

if channels == 1 && bitsPerPixel <= 8
    needed = width * height;
    if numel(raw) < needed
        error('Image buffer is smaller than expected.');
    end
    frame = reshape(raw(1:needed), [width, height])';
elseif channels == 1 && bitsPerPixel <= 16
    needed = 2 * width * height;
    if numel(raw) < needed
        error('Image buffer is smaller than expected.');
    end
    values = typecast(raw(1:needed), 'uint16');
    frame = reshape(values, [width, height])';
elseif channels >= 3
    needed = width * height * channels;
    if numel(raw) < needed
        error('Image buffer is smaller than expected.');
    end
    rgb = reshape(raw(1:needed), [channels, width, height]);
    frame = permute(rgb, [3, 2, 1]);
    if size(frame, 3) > 3
        frame = frame(:, :, 1:3);
    end
else
    error('Unsupported image format: %s, %d bits, %d channel(s).', ...
        pixelFormat, bitsPerPixel, channels);
end

info = struct( ...
    'Width', width, ...
    'Height', height, ...
    'BitsPerPixel', bitsPerPixel, ...
    'Channels', channels, ...
    'PixelFormat', pixelFormat, ...
    'FrameID', uint64(image.FrameID), ...
    'Timestamp', uint64(image.TimeStamp));
end
