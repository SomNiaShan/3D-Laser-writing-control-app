function phaseData = slm_translate_phase(phaseData, offsetXpx, offsetYpx)
%SLM_TRANSLATE_PHASE Move a phase map across the SLM panel by whole pixels.
%
% Positive offsetXpx moves the pattern right (higher columns) and positive
% offsetYpx moves it down (higher rows), as drawn in the previews. Pixels
% pushed past the panel edge are dropped and uncovered pixels get zero phase.

if nargin < 2 || isempty(offsetXpx)
    offsetXpx = 0;
end
if nargin < 3 || isempty(offsetYpx)
    offsetYpx = 0;
end
if ~isnumeric(phaseData) || ~ismatrix(phaseData)
    error('SLM:InvalidPhaseData', 'phaseData must be a 2-D numeric matrix.');
end
offsetXpx = localWholePixels(offsetXpx, 'offsetXpx');
offsetYpx = localWholePixels(offsetYpx, 'offsetYpx');
if offsetXpx == 0 && offsetYpx == 0
    return;
end

[heightPx, widthPx] = size(phaseData);
sourceRows = max(1, 1 - offsetYpx):min(heightPx, heightPx - offsetYpx);
sourceColumns = max(1, 1 - offsetXpx):min(widthPx, widthPx - offsetXpx);
translated = zeros(heightPx, widthPx, 'like', phaseData);
translated(sourceRows + offsetYpx, sourceColumns + offsetXpx) = ...
    phaseData(sourceRows, sourceColumns);
phaseData = translated;
end

function value = localWholePixels(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value ~= round(value)
    error('SLM:InvalidPatternOffset', '%s must be a whole number of pixels.', name);
end
value = double(value);
end
