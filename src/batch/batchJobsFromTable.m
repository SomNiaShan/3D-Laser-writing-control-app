function rows = batchJobsFromTable(tableHandle, enabledOnly)
if nargin < 2
    enabledOnly = true;
end
data = batchNormalizedTableData(tableHandle);
rows = repmat(emptyBatchJob(), 1, 0);
batchIndex = 0;
for tableIndex = 1:size(data, 1)
    job = batchJobFromDataRow(data(tableIndex, :), tableIndex);
    if enabledOnly && ~job.enabled
        continue;
    end
    batchIndex = batchIndex + 1;
    job.batchIndex = batchIndex;
    rows(end + 1) = job; %#ok<AGROW>
end
end
