function report = run_refactor_checks(options)
%RUN_REFACTOR_CHECKS Run static and no-hardware regression checks.

arguments
    options.IncludeStress (1, 1) logical = false
    options.IncludeScreenshots (1, 1) logical = false
end

refactorRoot = fileparts(mfilename('fullpath'));
projectRoot = refactorRoot;
addpath(fullfile(projectRoot, 'scripts'));
lw_setup_project();
addpath(fullfile(refactorRoot, 'tests'));

matlabFiles = dir(fullfile(refactorRoot, '**', '*.m'));
issueCount = 0;
for fileIndex = 1:numel(matlabFiles)
    filePath = fullfile(matlabFiles(fileIndex).folder, matlabFiles(fileIndex).name);
    issues = checkcode(filePath, '-id');
    issueCount = issueCount + numel(issues);
    for issueIndex = 1:numel(issues)
        fprintf('%s:%d %s %s\n', filePath, issues(issueIndex).line, ...
            issues(issueIndex).id, issues(issueIndex).message);
    end
end
if issueCount > 0
    error('lw:app:CodeAnalyzerFailure', 'Code Analyzer reported %d issue(s).', issueCount);
end

testFiles = dir(fullfile(refactorRoot, 'tests', 'Test*.m'));
if ~options.IncludeStress
    testFiles(strcmp({testFiles.name}, 'TestLifecycleStress.m')) = [];
end
testPaths = arrayfun(@(file) fullfile(file.folder, file.name), ...
    testFiles, 'UniformOutput', false);
results = runtests(testPaths);
assertSuccess(results);

screenshotResult = struct();
if options.IncludeScreenshots
    screenshotResult = compare_ui_screenshots();
end

report = struct( ...
    'codeAnalyzerFileCount', numel(matlabFiles), ...
    'codeAnalyzerIssueCount', issueCount, ...
    'testResults', results, ...
    'screenshotResult', screenshotResult);
end
