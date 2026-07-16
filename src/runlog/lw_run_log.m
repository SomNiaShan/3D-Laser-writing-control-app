function [runLog, varargout] = lw_run_log(action, varargin)
%LW_RUN_LOG Manage per-run machining logs for the laser writing app.

action = string(action);
varargout = {};

switch action
    case "empty"
        runLog = emptyRunLogState();

    case "begin"
        runLog = beginRunLog(varargin{:});

    case "message"
        runLog = appendRunLogMessage(varargin{:});

    case "event"
        runLog = appendRunLogEvent(varargin{:});

    case "progress"
        runLog = appendProgressEvent(varargin{:});

    case "paused"
        runLog = recordPaused(varargin{:});

    case "error"
        runLog = recordError(varargin{:});

    case "finalize"
        runLog = finalizeRunLog(varargin{:});

    case "target"
        runLog = varargin{1};
        varargout{1} = targetSnapshot(varargin{2}, varargin{3});

    otherwise
        error('lwRunLog:UnknownAction', 'Unknown run log action: %s.', char(action));
end
end

function runLog = emptyRunLogState()
runLog = struct( ...
    'active', false, ...
    'runId', "", ...
    'folder', "", ...
    'eventsLogFile', "", ...
    'eventsJsonlFile', "", ...
    'manifestFile', "", ...
    'preflightTextFile', "", ...
    'errorFile', "", ...
    'startedAt', "", ...
    'startTic', [], ...
    'preflight', [], ...
    'eventSequence', 0, ...
    'lastProgressLogTic', [], ...
    'lastProgressLogIndex', NaN, ...
    'startPosition', []);
end

function runLog = beginRunLog(~, preflight, state, config, projectRoot)
rootFolder = runLogRootFolder(config, projectRoot);
if ~isfolder(rootFolder)
    mkdir(rootFolder);
end

modeToken = "run";
if isfield(preflight, 'runMode')
    modeToken = string(preflight.runMode);
end
baseName = sprintf('%s_%s', ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')), ...
    sanitizeFileComponent(modeToken, 'run'));
runFolder = createUniqueRunLogFolder(rootFolder, baseName);

runLog = emptyRunLogState();
runLog.active = true;
runLog.runId = string(fileNameOnly(runFolder));
runLog.folder = string(runFolder);
runLog.eventsLogFile = string(fullfile(runFolder, 'events.log'));
runLog.eventsJsonlFile = string(fullfile(runFolder, 'events.jsonl'));
runLog.manifestFile = string(fullfile(runFolder, 'manifest.json'));
runLog.preflightTextFile = string(fullfile(runFolder, 'preflight.txt'));
runLog.errorFile = string(fullfile(runFolder, 'error.txt'));
runLog.startedAt = runLogTimestamp();
runLog.startTic = tic;
runLog.preflight = preflight;
runLog.startPosition = targetSnapshot(state.currentPosition, config);

writeTextFile(runLog.preflightTextFile, string(preflight.summaryText));
writePlanSnapshots(runLog, preflight, config);
writeManifest(runLog, "running", [], state, config, []);
runLog = appendRunLogEvent(runLog, 'run_created', struct( ...
    'runMode', char(modeToken), ...
    'folder', char(runLog.folder), ...
    'startPosition', runLog.startPosition));
end

function rootFolder = runLogRootFolder(config, projectRoot)
rootFolder = fullfile(projectRoot, 'outputs', 'run_logs');
if isfield(config, 'logging') && isfield(config.logging, 'runLogFolder')
    configuredFolder = char(strtrim(string(config.logging.runLogFolder)));
    if ~isempty(configuredFolder)
        rootFolder = configuredFolder;
    end
end
end

function seconds = progressPeriodSeconds(config)
seconds = 1.0;
if isfield(config, 'logging') && isfield(config.logging, 'progressPeriodSeconds')
    candidate = double(config.logging.progressPeriodSeconds);
    if isscalar(candidate) && isfinite(candidate) && candidate > 0
        seconds = candidate;
    end
end
end

function folder = createUniqueRunLogFolder(rootFolder, baseName)
folder = fullfile(rootFolder, char(baseName));
suffix = 1;
while isfolder(folder)
    suffix = suffix + 1;
    folder = fullfile(rootFolder, sprintf('%s_%03d', char(baseName), suffix));
end
mkdir(folder);
end

function name = fileNameOnly(pathValue)
[~, name, ext] = fileparts(char(pathValue));
name = [name ext];
end

function timestamp = runLogTimestamp()
timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
end

function runLog = appendRunLogMessage(runLog, line, message)
if ~isActive(runLog)
    return;
end

try
    appendTextFileLine(runLog.eventsLogFile, line);
catch
end

try
    runLog = appendRunLogEvent(runLog, 'message', struct('message', char(string(message))));
catch
end
end

function runLog = appendRunLogEvent(runLog, eventName, data)
if ~isActive(runLog)
    return;
end
if nargin < 3 || isempty(data)
    data = struct();
end

runLog.eventSequence = runLog.eventSequence + 1;
entry = struct( ...
    'sequence', runLog.eventSequence, ...
    'timestamp', char(runLogTimestamp()), ...
    'runId', char(runLog.runId), ...
    'event', char(string(eventName)), ...
    'data', data);

try
    jsonText = jsonencode(entry);
catch ME
    entry.data = struct( ...
        'encodingError', compactErrorMessage(ME), ...
        'eventName', char(string(eventName)));
    jsonText = jsonencode(entry);
end
appendTextFileLine(runLog.eventsJsonlFile, jsonText);
end

function runLog = appendProgressEvent(runLog, index, total, target, phase, completedUnits, config)
if ~isActive(runLog) || total <= 0
    return;
end

index = max(0, min(round(double(index)), double(total)));
phase = string(phase);
milestoneStep = max(1, ceil(double(total) / 100));
shouldLog = isempty(runLog.lastProgressLogTic) || index == 0 || ...
    index >= total || abs(index - runLog.lastProgressLogIndex) >= milestoneStep;
if ~shouldLog && toc(runLog.lastProgressLogTic) >= progressPeriodSeconds(config)
    shouldLog = true;
end
if ~shouldLog
    return;
end

runLog.lastProgressLogTic = tic;
runLog.lastProgressLogIndex = index;
runLog = appendRunLogEvent(runLog, 'progress', struct( ...
    'index', index, ...
    'total', double(total), ...
    'phase', char(phase), ...
    'completedUnits', completedUnits, ...
    'target', targetSnapshot(target, config)));
end

function runLog = recordPaused(runLog, runMode, runResult, state, config)
if ~isActive(runLog)
    return;
end

runLog = appendRunLogEvent(runLog, 'run_paused', struct( ...
    'runMode', char(string(runMode)), ...
    'returnTarget', targetSnapshot(runResult.returnTarget, config), ...
    'resumeContext', resumeContextSummary(runResult.resumeContext, config)));
writeManifest(runLog, "paused", runResult, state, config, []);
end

function runLog = recordError(runLog, err, closeAfter, runResult, state, config)
if ~isActive(runLog)
    return;
end

runLog = appendRunLogEvent(runLog, 'run_error', struct( ...
    'closeAfter', logical(closeAfter), ...
    'error', errorStruct(err)));
try
    writeTextFile(runLog.errorFile, errorText(err));
catch
end

if closeAfter
    runLog = finalizeRunLog(runLog, "error", runResult, state, config, err);
else
    writeManifest(runLog, "error_waiting_for_resume", [], state, config, err);
end
end

function runLog = finalizeRunLog(runLog, status, runResult, state, config, err)
if ~isActive(runLog)
    return;
end
if nargin < 3
    runResult = [];
end
if nargin < 6
    err = [];
end

runLog = appendRunLogEvent(runLog, 'run_finalized', struct( ...
    'status', char(string(status)), ...
    'result', resultStruct(status, runResult, config), ...
    'error', optionalErrorStruct(err)));
writeManifest(runLog, status, runResult, state, config, err);
runLog = emptyRunLogState();
end

function writeManifest(runLog, status, runResult, state, config, err)
manifest = buildManifest(runLog, status, runResult, state, config, err);
writeTextFile(runLog.manifestFile, prettyJsonEncode(manifest));
end

function manifest = buildManifest(runLog, status, runResult, state, config, err)
preflight = runLog.preflight;
manifest = struct();
manifest.runId = char(runLog.runId);
manifest.status = char(string(status));
manifest.startedAt = char(runLog.startedAt);
manifest.updatedAt = char(runLogTimestamp());
manifest.durationSeconds = runDurationSeconds(runLog);
manifest.files = fileManifest(runLog);
manifest.app = struct( ...
    'name', '3D Laser Writing Control App', ...
    'matlabVersion', version, ...
    'computer', computer, ...
    'user', getenv('USERNAME'));
manifest.hardware = hardwareManifest(state, config, preflight);
manifest.plan = planManifest(preflight, config);
manifest.positions = struct( ...
    'start', runLog.startPosition, ...
    'current', targetSnapshot(state.currentPosition, config));
manifest.result = resultStruct(status, runResult, config);
manifest.error = optionalErrorStruct(err);
end

function files = fileManifest(runLog)
files = struct( ...
    'folder', char(runLog.folder), ...
    'manifest', char(runLog.manifestFile), ...
    'eventsLog', char(runLog.eventsLogFile), ...
    'eventsJsonl', char(runLog.eventsJsonlFile), ...
    'preflightText', char(runLog.preflightTextFile));
maybeFiles = {
    'trajectory', fullfile(char(runLog.folder), 'trajectory.csv')
    'cutPlan', fullfile(char(runLog.folder), 'cut_plan.csv')
    'zSweepJobs', fullfile(char(runLog.folder), 'z_sweep_jobs.csv')
    'error', char(runLog.errorFile)
    };
for i = 1:size(maybeFiles, 1)
    if isfile(maybeFiles{i, 2})
        files.(maybeFiles{i, 1}) = maybeFiles{i, 2};
    end
end
end

function seconds = runDurationSeconds(runLog)
seconds = NaN;
if ~isempty(runLog.startTic)
    seconds = toc(runLog.startTic);
end
end

function manifest = hardwareManifest(state, config, preflight)
manifest = struct();
manifest.connected = struct( ...
    'stages', isfield(state, 'axes') && isstruct(state.axes) && ...
        isfield(state.axes, 'x') && ~isempty(state.axes.x) && ...
        isfield(state.axes, 'y') && ~isempty(state.axes.y) && ...
        isfield(state.axes, 'z') && ~isempty(state.axes.z), ...
    'daq', isfield(state, 'daq') && ~isempty(state.daq), ...
    'carbide', isfield(state, 'carbide') && isstruct(state.carbide) && ...
        isfield(state.carbide, 'connected') && logical(state.carbide.connected), ...
    'flir', isfield(state, 'flir') && isstruct(state.flir) && ...
        isfield(state.flir, 'isConnected') && logical(state.flir.isConnected));
manifest.config = configManifest(config);
manifest.marks = marksSnapshot(state, config);
if isfield(preflight, 'carbideSnapshot')
    manifest.carbideSnapshotAtPreflight = preflight.carbideSnapshot;
end
if isfield(state, 'carbide') && isstruct(state.carbide) && ...
        isfield(state.carbide, 'lastBasic') && ~isempty(state.carbide.lastBasic)
    manifest.carbideBasicCurrent = state.carbide.lastBasic;
end
end

function out = configManifest(config)
out = struct();
names = {'stage', 'daq', 'carbide', 'motion', 'execution', 'logging'};
for i = 1:numel(names)
    if isfield(config, names{i})
        out.(names{i}) = config.(names{i});
    end
end
end

function manifest = planManifest(preflight, config)
manifest = struct();
if isfield(preflight, 'runMode')
    manifest.runMode = char(string(preflight.runMode));
end
if isfield(preflight, 'summaryText')
    manifest.preflightSummary = char(string(preflight.summaryText));
end
manifest.progressTotal = progressTotal(preflight);
if isfield(preflight, 'motion')
    manifest.motion = preflight.motion;
end
if isfield(preflight, 'analysis')
    manifest.analysis = preflight.analysis;
end
if isfield(preflight, 'trajectory')
    manifest.trajectory = trajectorySummary(preflight.trajectory, config);
end
if isfield(preflight, 'pauseSeconds')
    manifest.point = struct( ...
        'pauseSeconds', preflight.pauseSeconds, ...
        'exposureTimeSeconds', preflight.exposureTimeSeconds, ...
        'exposureMicroseconds', preflight.exposureMicroseconds);
end
if isfield(preflight, 'pulseSpeedMmPerSecond')
    manifest.stream = struct( ...
        'pulseSpeedMmPerSecond', preflight.pulseSpeedMmPerSecond, ...
        'powerPercent', preflight.powerPercent, ...
        'ttlGateWidthUs', preflight.ttlGateWidthUs, ...
        'maxLaserRepetitionRateKHz', preflight.maxLaserRepetitionRateKHz, ...
        'maxTriggerRateHz', preflight.maxTriggerRateHz, ...
        'requiredTriggerRateHz', preflight.requiredTriggerRateHz, ...
        'minIntervalSeconds', preflight.minIntervalSeconds);
end
if isfield(preflight, 'cutPlan') && istable(preflight.cutPlan)
    manifest.cutPlan = struct( ...
        'rowCount', height(preflight.cutPlan), ...
        'groupCount', cutGroupCount(preflight), ...
        'variableNames', {preflight.cutPlan.Properties.VariableNames});
end
if isfield(preflight, 'sweep')
    manifest.zSweep = sweepSummary(preflight.sweep, config);
end
if isfield(preflight, 'matrix')
    manifest.zSweepMatrix = matrixSummary(preflight.matrix);
end
if isfield(preflight, 'sweepJobs')
    manifest.zSweepJobs = struct( ...
        'count', numel(preflight.sweepJobs), ...
        'exposedSweepCount', numericField(preflight, 'exposedSweepCount', NaN), ...
        'progressTotal', numericField(preflight, 'progressTotal', NaN));
end
end

function total = progressTotal(preflight)
if isfield(preflight, 'progressTotal')
    total = preflight.progressTotal;
elseif isfield(preflight, 'trajectory')
    total = numel(preflight.trajectory.x);
else
    total = NaN;
end
end

function count = cutGroupCount(preflight)
if isfield(preflight, 'cutGroups')
    count = numel(preflight.cutGroups);
else
    count = NaN;
end
end

function summary = trajectorySummary(traj, config)
summary = struct();
summary.pointCount = numel(traj.x);
if isfield(traj, 'sourceType')
    summary.sourceType = char(string(traj.sourceType));
end
if isfield(traj, 'modeSupport')
    summary.modeSupport = char(string(traj.modeSupport));
end
if isfield(traj, 'meta') && isstruct(traj.meta)
    summary.meta = traj.meta;
end
summary.x = valueRange(traj.x);
summary.yStage = valueRange(traj.y);
summary.yDisplay = valueRange(yDisplayFromStage(traj.y, config));
summary.z = valueRange(traj.z);
if isfield(traj, 'power')
    summary.powerPercent = valueRange(traj.power);
end
if summary.pointCount > 0
    summary.firstPoint = trajectoryPoint(traj, 1, config);
    summary.lastPoint = trajectoryPoint(traj, summary.pointCount, config);
end
end

function point = trajectoryPoint(traj, index, config)
point = struct( ...
    'index', index, ...
    'x', traj.x(index), ...
    'yStage', traj.y(index), ...
    'yDisplay', yDisplayFromStage(traj.y(index), config), ...
    'z', traj.z(index), ...
    'powerPercent', NaN);
if isfield(traj, 'power') && numel(traj.power) >= index
    point.powerPercent = traj.power(index);
end
end

function summary = sweepSummary(sweep, config)
summary = struct( ...
    'x', numericField(sweep, 'x', NaN), ...
    'yStage', numericField(sweep, 'y', NaN), ...
    'yDisplay', numericField(sweep, 'displayY', NaN), ...
    'zBack', numericField(sweep, 'zBack', NaN), ...
    'zFront', numericField(sweep, 'zFront', NaN), ...
    'repeatCount', numericField(sweep, 'repeatCount', NaN), ...
    'sweepSpeedMmPerSecond', numericField(sweep, 'sweepSpeedMmPerSecond', NaN), ...
    'returnSpeedMmPerSecond', numericField(sweep, 'returnSpeedMmPerSecond', NaN), ...
    'powerPercent', numericField(sweep, 'powerPercent', NaN), ...
    'exposureDirection', char(stringField(sweep, 'exposureDirection', "")), ...
    'zAcceleration', numericField(sweep, 'zAcceleration', NaN));
if isnan(summary.yDisplay) && isfinite(summary.yStage)
    summary.yDisplay = yDisplayFromStage(summary.yStage, config);
end
end

function summary = matrixSummary(matrix)
summary = matrix;
if isfield(summary, 'runs')
    summary = rmfield(summary, 'runs');
end
end

function marks = marksSnapshot(state, config)
marks = struct();
if ~isfield(state, 'marks') || ~isstruct(state.marks)
    return;
end
names = {'mark0', 'mark1', 'mark2'};
for i = 1:numel(names)
    name = names{i};
    if isfield(state.marks, name) && isnumeric(state.marks.(name)) && numel(state.marks.(name)) >= 3
        value = state.marks.(name);
        marks.(name) = targetSnapshot(struct('x', value(1), 'y', value(2), 'z', value(3)), config);
    else
        marks.(name) = [];
    end
end
end

function result = resultStruct(status, runResult, config)
result = struct('status', char(string(status)));
if isstruct(runResult)
    if isfield(runResult, 'returnTarget')
        result.returnTarget = targetSnapshot(runResult.returnTarget, config);
    end
    if isfield(runResult, 'resumeContext')
        result.resumeContext = resumeContextSummary(runResult.resumeContext, config);
    end
end
end

function summary = resumeContextSummary(resumeContext, config)
summary = struct();
if isempty(resumeContext) || ~isstruct(resumeContext)
    return;
end
fields = {'kind', 'runMode', 'nextPointIndex', 'nextCutIndex', 'jobIndex', 'stepIndex', 'progressOffset'};
for i = 1:numel(fields)
    if isfield(resumeContext, fields{i})
        summary.(fields{i}) = resumeContext.(fields{i});
    end
end
if isfield(resumeContext, 'returnTarget')
    summary.returnTarget = targetSnapshot(resumeContext.returnTarget, config);
end
end

function target = targetSnapshot(position, config)
target = struct('x', NaN, 'yStage', NaN, 'yDisplay', NaN, 'z', NaN);
if isempty(position) || ~isstruct(position)
    return;
end
if isfield(position, 'x')
    target.x = double(position.x);
end
if isfield(position, 'y')
    target.yStage = double(position.y);
    target.yDisplay = yDisplayFromStage(target.yStage, config);
end
if isfield(position, 'z')
    target.z = double(position.z);
end
end

function range = valueRange(values)
values = double(values(:));
finiteValues = values(isfinite(values));
range = struct('min', NaN, 'max', NaN, 'mean', NaN);
if isempty(finiteValues)
    return;
end
range.min = min(finiteValues);
range.max = max(finiteValues);
range.mean = mean(finiteValues);
end

function value = numericField(source, fieldName, defaultValue)
value = defaultValue;
if isstruct(source) && isfield(source, fieldName)
    candidate = source.(fieldName);
    if isnumeric(candidate) && isscalar(candidate)
        value = double(candidate);
    end
end
end

function value = stringField(source, fieldName, defaultValue)
value = string(defaultValue);
if isstruct(source) && isfield(source, fieldName)
    value = string(source.(fieldName));
end
end

function yDisplay = yDisplayFromStage(yStage, config)
yDisplayReference = 25;
if isfield(config, 'motion') && isfield(config.motion, 'yDisplayReference')
    yDisplayReference = config.motion.yDisplayReference;
end
yDisplay = yDisplayReference - yStage;
end

function writePlanSnapshots(runLog, preflight, config)
if isfield(preflight, 'trajectory')
    try
        writeTrajectorySnapshot(preflight.trajectory, fullfile(char(runLog.folder), 'trajectory.csv'), config);
    catch ME
        appendRunLogEvent(runLog, 'snapshot_write_warning', struct( ...
            'file', 'trajectory.csv', ...
            'message', compactErrorMessage(ME)));
    end
end

if isfield(preflight, 'cutPlan') && istable(preflight.cutPlan)
    try
        writeCutPlanSnapshot(preflight.cutPlan, fullfile(char(runLog.folder), 'cut_plan.csv'), config);
    catch ME
        appendRunLogEvent(runLog, 'snapshot_write_warning', struct( ...
            'file', 'cut_plan.csv', ...
            'message', compactErrorMessage(ME)));
    end
end

if isfield(preflight, 'sweepJobs')
    try
        writeZSweepJobSnapshot(preflight.sweepJobs, fullfile(char(runLog.folder), 'z_sweep_jobs.csv'), config);
    catch ME
        appendRunLogEvent(runLog, 'snapshot_write_warning', struct( ...
            'file', 'z_sweep_jobs.csv', ...
            'message', compactErrorMessage(ME)));
    end
end
end

function writeTrajectorySnapshot(traj, outputPath, config)
pointCount = numel(traj.x);
powerValues = nan(pointCount, 1);
if isfield(traj, 'power') && numel(traj.power) == pointCount
    powerValues = traj.power(:);
end

index = (1:pointCount).';
x = traj.x(:);
yStage = traj.y(:);
yDisplay = yDisplayFromStage(yStage, config);
z = traj.z(:);
powerPercent = powerValues(:);
snapshotTable = table(index, x, yStage, yDisplay, z, powerPercent, ...
    'VariableNames', {'Index', 'X', 'YStage', 'YDisplay', 'Z', 'PowerPercent'});
writetable(snapshotTable, outputPath);
end

function writeCutPlanSnapshot(cutPlan, outputPath, config)
snapshotTable = cutPlan;
stageNames = {'y', 'y2', 'leadY', 'exitY'};
displayNames = {'yDisplay', 'y2Display', 'leadYDisplay', 'exitYDisplay'};
for i = 1:numel(stageNames)
    if ismember(stageNames{i}, snapshotTable.Properties.VariableNames)
        snapshotTable.(displayNames{i}) = yDisplayFromStage(snapshotTable.(stageNames{i}), config);
    end
end
writetable(snapshotTable, outputPath);
end

function writeZSweepJobSnapshot(jobs, outputPath, config)
jobs = jobs(:);
jobCount = numel(jobs);
index = zeros(jobCount, 1);
x = nan(jobCount, 1);
yStage = nan(jobCount, 1);
yDisplay = nan(jobCount, 1);
zBack = nan(jobCount, 1);
zFront = nan(jobCount, 1);
powerPercent = nan(jobCount, 1);
sweepSpeedMmPerSecond = nan(jobCount, 1);
returnSpeedMmPerSecond = nan(jobCount, 1);
repeatCount = nan(jobCount, 1);
exposureDirection = strings(jobCount, 1);
blockIndex = nan(jobCount, 1);
blockColumn = nan(jobCount, 1);
blockRow = nan(jobCount, 1);
xValueText = strings(jobCount, 1);
yValueText = strings(jobCount, 1);
blockText = strings(jobCount, 1);

for jobIndex = 1:jobCount
    job = jobs(jobIndex);
    sweep = job.sweep;
    index(jobIndex) = numericField(job, 'index', jobIndex);
    x(jobIndex) = numericField(sweep, 'x', NaN);
    yStage(jobIndex) = numericField(sweep, 'y', NaN);
    if isfield(sweep, 'displayY')
        yDisplay(jobIndex) = double(sweep.displayY);
    else
        yDisplay(jobIndex) = yDisplayFromStage(yStage(jobIndex), config);
    end
    zBack(jobIndex) = numericField(sweep, 'zBack', NaN);
    zFront(jobIndex) = numericField(sweep, 'zFront', NaN);
    powerPercent(jobIndex) = numericField(sweep, 'powerPercent', NaN);
    sweepSpeedMmPerSecond(jobIndex) = numericField(sweep, 'sweepSpeedMmPerSecond', NaN);
    returnSpeedMmPerSecond(jobIndex) = numericField(sweep, 'returnSpeedMmPerSecond', NaN);
    repeatCount(jobIndex) = numericField(sweep, 'repeatCount', NaN);
    exposureDirection(jobIndex) = stringField(sweep, 'exposureDirection', "");
    blockIndex(jobIndex) = numericField(job, 'blockIndex', NaN);
    blockColumn(jobIndex) = numericField(job, 'blockColumn', NaN);
    blockRow(jobIndex) = numericField(job, 'blockRow', NaN);
    xValueText(jobIndex) = stringField(job, 'xValueText', "");
    yValueText(jobIndex) = stringField(job, 'yValueText', "");
    blockText(jobIndex) = stringField(job, 'blockText', "");
end

snapshotTable = table(index, x, yStage, yDisplay, zBack, zFront, ...
    powerPercent, sweepSpeedMmPerSecond, returnSpeedMmPerSecond, repeatCount, ...
    exposureDirection, blockIndex, blockColumn, blockRow, xValueText, yValueText, blockText, ...
    'VariableNames', {'Index', 'X', 'YStage', 'YDisplay', 'ZBack', 'ZFront', ...
    'PowerPercent', 'SweepSpeedMmPerSecond', 'ReturnSpeedMmPerSecond', 'RepeatCount', ...
    'ExposureDirection', 'BlockIndex', 'BlockColumn', 'BlockRow', ...
    'XValueText', 'YValueText', 'BlockText'});
writetable(snapshotTable, outputPath);
end

function value = optionalErrorStruct(err)
value = [];
if ~isempty(err)
    value = errorStruct(err);
end
end

function info = errorStruct(err)
if isa(err, 'MException')
    info.message = err.message;
    info.identifier = err.identifier;
    info.stack = err.stack;
else
    info = struct('message', char(string(err)), 'identifier', '', 'stack', []);
end
end

function textValue = errorText(err)
if ~isa(err, 'MException')
    textValue = string(err);
    return;
end

stackLines = strings(numel(err.stack), 1);
for i = 1:numel(err.stack)
    frame = err.stack(i);
    stackLines(i) = sprintf('  %s:%d (%s)', frame.file, frame.line, frame.name);
end
lines = [
    sprintf('Identifier: %s', err.identifier)
    sprintf('Message: %s', err.message)
    "Stack:"
    stackLines
    ];
textValue = strjoin(lines, newline);
end

function textValue = prettyJsonEncode(value)
try
    textValue = jsonencode(value, 'PrettyPrint', true);
catch
    textValue = jsonencode(value);
end
end

function writeTextFile(filePath, textValue)
fileId = fopen(char(filePath), 'w');
if fileId < 0
    error('lwRunLog:FileOpenFailed', 'Could not open file for writing: %s', char(filePath));
end
cleanupObj = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', char(string(textValue)));
end

function appendTextFileLine(filePath, lineText)
fileId = fopen(char(filePath), 'a');
if fileId < 0
    error('lwRunLog:FileOpenFailed', 'Could not open file for appending: %s', char(filePath));
end
cleanupObj = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', char(string(lineText)));
end

function textValue = sanitizeFileComponent(rawValue, fallback)
textValue = char(strtrim(string(rawValue)));
if isempty(textValue)
    textValue = fallback;
end
textValue = regexprep(textValue, '[^\w\.=-]+', '_');
textValue = regexprep(textValue, '_+', '_');
textValue = regexprep(textValue, '^_+|_+$', '');
if isempty(textValue)
    textValue = fallback;
end
end

function tf = isActive(runLog)
tf = isstruct(runLog) && isfield(runLog, 'active') && logical(runLog.active);
end
