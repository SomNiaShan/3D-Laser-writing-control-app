function name = nextBatchDuplicateName(rawName, rowIndex)
baseName = sanitizeFileComponent(rawName, sprintf('beam_%03d', rowIndex));
name = sprintf('%s_copy_%03d', baseName, rowIndex);
end
