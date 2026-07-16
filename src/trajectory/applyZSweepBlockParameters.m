function sweep = applyZSweepBlockParameters(sweep, blockConfig, blockColumn, blockRow)
if ~blockConfig.enabled
    return;
end

if blockConfig.xParameter ~= "None"
    sweep = applyZSweepMatrixParameter( ...
        sweep, blockConfig.xParameter, blockConfig.xValues(blockColumn));
end

if blockConfig.yParameter ~= "None"
    sweep = applyZSweepMatrixParameter( ...
        sweep, blockConfig.yParameter, blockConfig.yValues(blockRow));
end
end
