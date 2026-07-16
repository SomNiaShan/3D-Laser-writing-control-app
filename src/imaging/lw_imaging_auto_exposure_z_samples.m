function zSamples = lw_imaging_auto_exposure_z_samples(zPositions, sampleCount)
%LW_IMAGING_AUTO_EXPOSURE_Z_SAMPLES Choose representative Z samples.

zPositions = zPositions(:).';
if isempty(zPositions)
    zSamples = [];
    return;
end

sampleCount = min(max(1, round(double(sampleCount))), numel(zPositions));
if sampleCount == 1
    indices = round((numel(zPositions) + 1) / 2);
elseif sampleCount >= numel(zPositions)
    indices = 1:numel(zPositions);
else
    indices = unique(round(linspace(1, numel(zPositions), sampleCount)));
end
zSamples = zPositions(indices);
end
