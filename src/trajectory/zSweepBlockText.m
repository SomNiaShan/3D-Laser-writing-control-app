function textValue = zSweepBlockText(blockConfig, blockIndex)
if ~blockConfig.enabled
    textValue = "";
    return;
end

blockColumn = mod(blockIndex - 1, blockConfig.columns) + 1;
blockRow = floor((blockIndex - 1) / blockConfig.columns) + 1;
textParts = strings(1, 0);
if blockConfig.xParameter ~= "None"
    value = blockConfig.xValues(blockColumn);
    textParts(end + 1) = sprintf('%s=%s', ...
        char(blockConfig.xParameter), char(zSweepMatrixValueText(blockConfig.xParameter, value)));
end
if blockConfig.yParameter ~= "None"
    value = blockConfig.yValues(blockRow);
    textParts(end + 1) = sprintf('%s=%s', ...
        char(blockConfig.yParameter), char(zSweepMatrixValueText(blockConfig.yParameter, value)));
end
textValue = strjoin(textParts, ', ');
end
