function trajectory = lw_generate_mark_trajectory(textString, pitchMm, powerPercent)
%LW_GENERATE_MARK_TRAJECTORY Build a simple 5x7 dot-matrix mark trajectory.

textString = string(textString);
if strlength(textString) == 0
    error('Mark text cannot be empty.');
end
powerPercent = validatePowerPercent(powerPercent, 'Mark power');

font = lw_builtin_5x7_font();
chars = char(textString);
unsupportedChars = char.empty(1, 0);

for i = 1:numel(chars)
    ch = chars(i);
    if ~isKey(font, ch)
        unsupportedChars(end + 1) = ch; %#ok<AGROW>
    end
end

unsupportedChars = unique(unsupportedChars, 'stable');
if ~isempty(unsupportedChars)
    unsupportedText = strjoin(cellstr(unsupportedChars(:)), ', ');
    error('Unsupported characters in Mark Text: %s', unsupportedText);
end

coords = zeros(0, 2);
xOffset = 0;

for i = 1:numel(chars)
    ch = chars(i);
    glyph = font(ch);
    [r, c] = find(glyph);
    xLocal = (c - 1) * pitchMm + xOffset;
    yLocal = (size(glyph, 1) - r) * pitchMm;
    coords = [coords; xLocal, yLocal]; %#ok<AGROW>
    xOffset = xOffset + size(glyph, 2) * pitchMm + pitchMm;
end

z = zeros(size(coords, 1), 1);
meta = struct( ...
    'text', textString, ...
    'pitchMm', pitchMm, ...
    'powerSource', "plan", ...
    'font', "builtin_5x7");
trajectory = lw_make_trajectory(coords(:, 1), coords(:, 2), z, ...
    powerPercent, "mark_text", "point+stream", meta);
end
