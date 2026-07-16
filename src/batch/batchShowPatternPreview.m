function batchShowPatternPreview(targetAxes, pattern, labelText)
phaseUnit = batchPatternPhaseUnit(pattern, []);
phasePreview = mod(double(pattern.phaseData), double(phaseUnit));
imagesc(targetAxes, phasePreview);
axis(targetAxes, 'image');
targetAxes.XTick = [];
targetAxes.YTick = [];
colormap(targetAxes, gray(256));
title(targetAxes, labelText, 'Interpreter', 'none');
end
