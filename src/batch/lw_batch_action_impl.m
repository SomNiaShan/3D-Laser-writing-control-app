function lw_batch_action_impl(fig, action, ui, apiFcn, varargin)
action = string(action);
controllerState = readControllerState(fig);

switch action
    case "tableSelection"
        controllerState.selectedRows = selectedRowsFromEvent(varargin{:});
        writeControllerState(fig, controllerState);

    case "tableEdited"
        callApi(apiFcn, "updateBatchSummary");

    case "addRow"
        data = batchNormalizedTableData(ui.BatchSlmTable);
        data(end + 1, :) = batchDefaultRow(size(data, 1) + 1);
        batchSetTableData(ui.BatchSlmTable, data);
        controllerState.selectedRows = size(data, 1);
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "updateBatchSummary");

    case "duplicateRow"
        data = batchNormalizedTableData(ui.BatchSlmTable);
        selectedRow = batchSelectedRowIndex(ui.BatchSlmTable, controllerState.selectedRows);
        if isempty(selectedRow)
            error('Select a batch row first.');
        end
        newRow = data(selectedRow, :);
        nameColumn = batchColumnIndex('Name');
        newRow{nameColumn} = nextBatchDuplicateName(newRow{nameColumn}, size(data, 1) + 1);
        data = [data(1:selectedRow, :); newRow; data(selectedRow + 1:end, :)];
        batchSetTableData(ui.BatchSlmTable, data);
        controllerState.selectedRows = selectedRow + 1;
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "updateBatchSummary");

    case "deleteRow"
        data = batchNormalizedTableData(ui.BatchSlmTable);
        if isempty(data)
            return;
        end
        selectedRows = batchSelectedRowIndices(ui.BatchSlmTable, controllerState.selectedRows);
        if isempty(selectedRows)
            error('Select one or more batch rows first.');
        end
        data(selectedRows, :) = [];
        batchSetTableData(ui.BatchSlmTable, data);
        controllerState.selectedRows = min(selectedRows(1), size(data, 1));
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "updateBatchSummary");

    case "moveRow"
        direction = varargin{1};
        data = batchNormalizedTableData(ui.BatchSlmTable);
        selectedRow = batchSelectedRowIndex(ui.BatchSlmTable, controllerState.selectedRows);
        if isempty(selectedRow)
            error('Select a batch row first.');
        end
        targetRow = selectedRow + direction;
        if targetRow < 1 || targetRow > size(data, 1)
            return;
        end
        tempRow = data(selectedRow, :);
        data(selectedRow, :) = data(targetRow, :);
        data(targetRow, :) = tempRow;
        batchSetTableData(ui.BatchSlmTable, data);
        controllerState.selectedRows = targetRow;
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "updateBatchSummary");

    case "importCsv"
        [fileName, folderName] = uigetfile( ...
            {'*.csv', 'CSV Files (*.csv)'; '*.*', 'All Files (*.*)'}, ...
            'Import SLM batch table');
        if isequal(fileName, 0) || isequal(folderName, 0)
            return;
        end
        inputPath = fullfile(folderName, fileName);
        importedTable = readtable(inputPath, 'TextType', 'string');
        batchSetTableData(ui.BatchSlmTable, batchDataFromImportedTable(importedTable));
        controllerState.selectedRows = [];
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "updateBatchSummary");
        callApi(apiFcn, "log", sprintf('Imported SLM batch table: %s', inputPath));

    case "exportCsv"
        timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        defaultName = sprintf('slm_batch_table_%s.csv', timestamp);
        [fileName, folderName] = uiputfile( ...
            {'*.csv', 'CSV Files (*.csv)'; '*.*', 'All Files (*.*)'}, ...
            'Export SLM batch table', defaultName);
        if isequal(fileName, 0) || isequal(folderName, 0)
            return;
        end
        outputPath = fullfile(folderName, fileName);
        writetable(batchUiDataAsTable(ui.BatchSlmTable), outputPath);
        callApi(apiFcn, "log", sprintf('Exported SLM batch table: %s', outputPath));

    case "validateTable"
        preflight = callApi(apiFcn, "buildPreflight", false);
        callApi(apiFcn, "log", sprintf('Batch validation passed: %d enabled row(s), %d total frame(s).', ...
            numel(preflight.jobs), preflight.totalFrames));
        uialert(fig, preflight.summaryText, 'Batch Validation');

    case "generateSweep"
        existingRows = batchNormalizedTableData(ui.BatchSlmTable);
        generatedRows = generateSweepRows(ui, controllerState.selectedRows, size(existingRows, 1));
        data = [existingRows; generatedRows];
        batchSetTableData(ui.BatchSlmTable, data);
        controllerState.selectedRows = (size(existingRows, 1) + 1):size(data, 1);
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "updateBatchSummary");
        callApi(apiFcn, "log", sprintf('Generated SLM batch sweep: appended %d row(s), %d total row(s).', ...
            size(generatedRows, 1), size(data, 1)));

    case "connectSlm"
        if callApi(apiFcn, "isBatchSlmConnected")
            callApi(apiFcn, "log", 'Batch SLM is already connected.');
            return;
        end
        slmCfg = slm_config();
        controllerState.slmCtx = slm_init(slmCfg);
        writeControllerState(fig, controllerState);
        callApi(apiFcn, "log", sprintf('Batch SLM connected: %d x %d px, wavelength %.1f nm.', ...
            controllerState.slmCtx.widthPx, controllerState.slmCtx.heightPx, ...
            controllerState.slmCtx.config.wavelengthNm));
        callApi(apiFcn, "syncAll");

    case {"disconnectSlm", "disconnectSlmSilent"}
        if ~hasSlmContext(controllerState)
            return;
        end
        slmCtx = controllerState.slmCtx;
        controllerState.slmCtx = [];
        writeControllerState(fig, controllerState);
        try
            slm_close(slmCtx);
        catch ME
            callApi(apiFcn, "syncAll");
            rethrow(ME);
        end
        if action ~= "disconnectSlmSilent"
            callApi(apiFcn, "log", 'Batch SLM disconnected.');
        end
        callApi(apiFcn, "syncAll");

    case "previewSelected"
        job = batchSelectedJobFromTable(ui.BatchSlmTable, controllerState.selectedRows);
        ctx = callApi(apiFcn, "patternContext", false);
        [~, ~, adjustedPattern] = batchApplySlmJob( ...
            job, ctx, false, callApi(apiFcn, "isFigValid"), callApi(apiFcn, "isBatchSlmConnected"));
        batchShowPatternPreview(ui.BatchPreviewAxes, adjustedPattern, sprintf('Preview: %s', job.name));
        callApi(apiFcn, "log", sprintf('Previewed SLM batch row %d: %s.', job.tableIndex, job.name));

    case "showSelected"
        requireBatchSlmConnected(apiFcn);
        job = batchSelectedJobFromTable(ui.BatchSlmTable, controllerState.selectedRows);
        ctx = callApi(apiFcn, "patternContext", true);
        [snapshot, ~, adjustedPattern] = batchApplySlmJob( ...
            job, ctx, true, callApi(apiFcn, "isFigValid"), callApi(apiFcn, "isBatchSlmConnected"));
        setappdata(0, callApi(apiFcn, "slmSnapshotKey"), snapshot);
        batchShowPatternPreview(ui.BatchPreviewAxes, adjustedPattern, sprintf('On SLM: %s', job.name));
        callApi(apiFcn, "log", sprintf('Showed SLM batch row %d on SLM: %s.', job.tableIndex, job.name));

    case "startBatch"
        startBatchImaging(fig, ui, apiFcn);

    otherwise
        error('Unknown batch action: %s.', action);
end
end

function rows = selectedRowsFromEvent(varargin)
rows = [];
try
    event = varargin{1};
    if isprop(event, 'Indices') && ~isempty(event.Indices)
        rows = unique(event.Indices(:, 1)).';
    end
catch
    rows = [];
end
end

function generatedRows = generateSweepRows(ui, selectedRows, rowIndexOffset)
if nargin < 3
    rowIndexOffset = 0;
end
parameterA = string(ui.BatchSweepParamADropDown.Value);
parameterB = string(ui.BatchSweepParamBDropDown.Value);
if parameterA == "None"
    error('Choose Param A before generating a sweep.');
end
if parameterA == parameterB
    error('Param A and Param B must be different.');
end

valuesA = signedNumericList(ui.BatchSweepValuesAField.Value, 'Param A values');
if parameterB == "None"
    valuesB = [];
else
    valuesB = signedNumericList(ui.BatchSweepValuesBField.Value, 'Param B values');
end

template = batchSelectedTemplateRow(ui.BatchSlmTable, selectedRows);
baseName = sanitizeFileComponent(ui.BatchSweepBaseNameField.Value, 'beam');
generatedRows = {};
rowIndex = 0;
if parameterB == "None"
    for aIndex = 1:numel(valuesA)
        rowIndex = rowIndex + 1;
        generatedRows(rowIndex, :) = batchSweepRow(template, rowIndexOffset + rowIndex, baseName, ...
            parameterA, valuesA(aIndex), "", NaN); %#ok<AGROW>
    end
else
    for aIndex = 1:numel(valuesA)
        for bIndex = 1:numel(valuesB)
            rowIndex = rowIndex + 1;
            generatedRows(rowIndex, :) = batchSweepRow(template, rowIndexOffset + rowIndex, baseName, ...
                parameterA, valuesA(aIndex), parameterB, valuesB(bIndex)); %#ok<AGROW>
        end
    end
end
end

function startBatchImaging(fig, ui, apiFcn)
resumeLive = callApi(apiFcn, "flirLive", 'pause', 'Paused for batch imaging');
liveCleanupObj = onCleanup(@() callApi(apiFcn, "flirLive", 'resume', resumeLive));
preflight = callApi(apiFcn, "buildPreflight", true);
choice = string(uiconfirm(fig, preflight.summaryText, 'Batch Imaging Preflight', ...
    'Options', {'Start', 'Cancel'}, ...
    'DefaultOption', 'Start', ...
    'CancelOption', 'Cancel', ...
    'Icon', 'question'));
if choice ~= "Start"
    callApi(apiFcn, "setStatus", "Preflight cancelled", "Preflight cancelled");
    callApi(apiFcn, "log", 'Batch imaging cancelled at preflight.');
    clear liveCleanupObj
    return;
end

callApi(apiFcn, "begin", preflight);
try
    executeBatchImaging(preflight, ui, apiFcn);
    callApi(apiFcn, "finishCleanup");
catch ME
    callApi(apiFcn, "finishCleanup");
    rethrow(ME);
end
clear liveCleanupObj
end

function executeBatchImaging(preflight, ui, apiFcn)
if ~isfolder(preflight.runFolder)
    mkdir(preflight.runFolder);
end
writetable(preflight.sourceTable, preflight.tableFile);

manifestRows = initialBatchManifestRows(preflight);
writetable(struct2table(manifestRows), preflight.manifestFile);
completedJobCount = 0;
capturedFrameCount = 0;
batchStatus = "finished";

for jobIndex = 1:numel(preflight.jobs)
    if callApi(apiFcn, "isStopRequested")
        batchStatus = "stopped";
        break;
    end

    job = preflight.jobs(jobIndex);
    manifestRows(jobIndex).Status = "running";
    manifestRows(jobIndex).StartedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    callApi(apiFcn, "setStatus", ...
        sprintf('%d / %d (Applying SLM)', jobIndex, numel(preflight.jobs)), ...
        sprintf('%03d | %s | Applying SLM', job.batchIndex, job.name));
    writetable(struct2table(manifestRows), preflight.manifestFile);

    try
        ctx = callApi(apiFcn, "patternContext", true);
        [snapshot, ~, adjustedPattern] = batchApplySlmJob( ...
            job, ctx, true, callApi(apiFcn, "isFigValid"), callApi(apiFcn, "isBatchSlmConnected"));
        setappdata(0, callApi(apiFcn, "slmSnapshotKey"), snapshot);
        batchShowPatternPreview(ui.BatchPreviewAxes, adjustedPattern, sprintf('On SLM: %s', job.name));
        if job.slmSettleSeconds > 0
            callApi(apiFcn, "setStatus", ...
                sprintf('%d / %d (SLM settling)', jobIndex, numel(preflight.jobs)), ...
                sprintf('%03d | %s | SLM settling', job.batchIndex, job.name));
            callApi(apiFcn, "pauseWithUi", job.slmSettleSeconds);
        end
        if callApi(apiFcn, "isStopRequested")
            manifestRows(jobIndex).Status = "stopped";
            batchStatus = "stopped";
            break;
        end

        imagingPreflight = callApi(apiFcn, "buildJobPreflight", preflight, job, snapshot);
        manifestRows(jobIndex).OutputFolder = string(imagingPreflight.runFolder);
        manifestRows(jobIndex).StackFile = string(imagingPreflight.stackFile);
        manifestRows(jobIndex).MetadataFile = string(fullfile(imagingPreflight.runFolder, 'metadata.csv'));
        writetable(struct2table(manifestRows), preflight.manifestFile);

        callApi(apiFcn, "setStatus", ...
            sprintf('%d / %d (Z stack)', jobIndex, numel(preflight.jobs)), ...
            sprintf('%03d | %s | Z stack', job.batchIndex, job.name));
        imagingResult = callApi(apiFcn, "execute3D", imagingPreflight);
        capturedFrameCount = capturedFrameCount + imagingResult.capturedCount;
        manifestRows(jobIndex).CapturedCount = imagingResult.capturedCount;
        manifestRows(jobIndex).TotalCount = imagingResult.totalCount;
        manifestRows(jobIndex).OutputFolder = string(imagingResult.outputFolder);
        manifestRows(jobIndex).StackFile = string(imagingResult.stackFile);
        manifestRows(jobIndex).MetadataFile = string(imagingResult.metadataFile);
        manifestRows(jobIndex).Exposure_us = imagingResult.actualExposureUs;
        manifestRows(jobIndex).AutoExposureEnabled = logical(imagingResult.autoExposureEnabled);
        manifestRows(jobIndex).AutoExposureScoutCount = imagingResult.autoExposureScoutCount;
        manifestRows(jobIndex).AutoExposureScoutFile = string(imagingResult.autoExposureScoutFile);
        manifestRows(jobIndex).FinishedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
        if string(imagingResult.status) == "stopped"
            manifestRows(jobIndex).Status = "stopped";
            batchStatus = "stopped";
            writetable(struct2table(manifestRows), preflight.manifestFile);
            break;
        end

        manifestRows(jobIndex).Status = "finished";
        completedJobCount = completedJobCount + 1;
        callApi(apiFcn, "setStatus", ...
            sprintf('%d / %d (Finished)', jobIndex, numel(preflight.jobs)), ...
            sprintf('%03d | %s | Finished', job.batchIndex, job.name));
        writetable(struct2table(manifestRows), preflight.manifestFile);
    catch ME
        manifestRows(jobIndex).Status = "failed";
        manifestRows(jobIndex).FinishedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
        manifestRows(jobIndex).Error = string(ME.message);
        writetable(struct2table(manifestRows), preflight.manifestFile);
        rethrow(ME);
    end
end

if callApi(apiFcn, "isStopRequested")
    batchStatus = "stopped";
end
writetable(struct2table(manifestRows), preflight.manifestFile);
if batchStatus == "stopped"
    callApi(apiFcn, "setStatus", ...
        sprintf('%d / %d (stopped)', completedJobCount, numel(preflight.jobs)), ...
        sprintf('Stopped after %d job(s), %d frame(s)', completedJobCount, capturedFrameCount));
    callApi(apiFcn, "log", sprintf('Batch imaging stopped after %d job(s), %d frame(s).', ...
        completedJobCount, capturedFrameCount));
else
    callApi(apiFcn, "setStatus", ...
        sprintf('%d / %d (Finished)', numel(preflight.jobs), numel(preflight.jobs)), ...
        sprintf('Finished: %d job(s), %d frame(s)', completedJobCount, capturedFrameCount));
    callApi(apiFcn, "log", sprintf('Batch imaging finished: %d job(s), %d frame(s).', ...
        completedJobCount, capturedFrameCount));
end
callApi(apiFcn, "setOutput", preflight.runFolder);
callApi(apiFcn, "log", sprintf('Batch manifest saved: %s', preflight.manifestFile));
end

function requireBatchSlmConnected(apiFcn)
if ~callApi(apiFcn, "isBatchSlmConnected")
    error('Batch SLM is not connected. Use Connect SLM in the Batch Imaging tab.');
end
end

function tf = hasSlmContext(controllerState)
tf = isstruct(controllerState) && isfield(controllerState, 'slmCtx') && ...
    isstruct(controllerState.slmCtx) && ~isempty(controllerState.slmCtx) && ...
    isfield(controllerState.slmCtx, 'slm') && isfield(controllerState.slmCtx, 'widthPx') && ...
    isfield(controllerState.slmCtx, 'heightPx');
end

function controllerState = readControllerState(fig)
controllerState = defaultControllerState();
try
    key = lw_batch_state_appdata_key();
    if isappdata(fig, key)
        storedState = getappdata(fig, key);
        if isstruct(storedState)
            controllerState = mergeControllerState(controllerState, storedState);
        end
    end
catch
end
end

function writeControllerState(fig, controllerState)
try
    setappdata(fig, lw_batch_state_appdata_key(), mergeControllerState(defaultControllerState(), controllerState));
catch
end
end

function controllerState = defaultControllerState()
controllerState = struct( ...
    'selectedRows', [], ...
    'slmCtx', []);
end

function controllerState = mergeControllerState(controllerState, storedState)
fieldNames = fieldnames(controllerState);
for index = 1:numel(fieldNames)
    fieldName = fieldNames{index};
    if isfield(storedState, fieldName)
        controllerState.(fieldName) = storedState.(fieldName);
    end
end
end

function varargout = callApi(apiFcn, action, varargin)
[varargout{1:nargout}] = apiFcn(action, varargin{:});
end
