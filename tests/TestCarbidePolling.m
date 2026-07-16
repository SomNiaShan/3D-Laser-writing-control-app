classdef TestCarbidePolling < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(refactorRoot, 'scripts'));
            lw_setup_project();
            helperPath = fullfile(refactorRoot, 'tests', 'helpers');
            addpath(helperPath);
            testCase.addTeardown(@() rmpath(helperPath));
        end
    end

    methods (Test)
        function nestedPollIsSkippedDuringSnapshotRefresh(testCase)
            requestCount = ValueBox(0);
            messages = ValueBox(strings(1, 0));
            controllerBox = ValueBox([]);
            getBasic = @(config) basicWithNestedPoll(config, controllerBox, requestCount);
            [controller, model] = makeController(getBasic, [], messages);
            controllerBox.Value = controller;

            controller.logCarbideRunStartSnapshot();

            testCase.verifyEqual(requestCount.Value, 1);
            testCase.verifyFalse(any(contains(messages.Value, 'status poll failed')));
            testCase.verifyEqual(model.State.carbide.pollFailureCount, 0);
            testCase.verifyTrue(model.State.carbide.connected);
        end

        function nestedPollIsSkippedDuringWriteRequest(testCase)
            basicRequestCount = ValueBox(0);
            writeCount = ValueBox(0);
            messages = ValueBox(strings(1, 0));
            controllerBox = ValueBox([]);
            getBasic = @(~) countedBasic(basicRequestCount);
            enableOutput = @(~) writeWithNestedPoll(controllerBox, writeCount);
            controller = makeController(getBasic, enableOutput, messages);
            controllerBox.Value = controller;

            controller.enableCarbideOutputImpl();

            testCase.verifyEqual(writeCount.Value, 1);
            testCase.verifyEqual(basicRequestCount.Value, 1);
            testCase.verifyFalse(any(contains(messages.Value, 'status poll failed')));
        end

        function failedRequestReleasesGuard(testCase)
            requestCount = ValueBox(0);
            messages = ValueBox(strings(1, 0));
            getBasic = @(~) failOnceThenReturnBasic(requestCount);
            controller = makeController(getBasic, [], messages);

            controller.logCarbideRunStartSnapshot();
            controller.logCarbideRunStartSnapshot();

            testCase.verifyEqual(requestCount.Value, 2);
            testCase.verifyTrue(any(contains(messages.Value, 'snapshot unavailable')));
            testCase.verifyTrue(any(contains(messages.Value, 'run start snapshot:')));
        end
    end
end

function [controller, model] = makeController(getBasic, enableOutput, messages)
state = lw_default_state();
state.carbide.connected = true;
state.carbide.baseUrl = "http://carbide.test/v1/";
state.carbide.lastBasic = validBasic();

carbideOverrides = struct('getBasic', getBasic);
if ~isempty(enableOutput)
    carbideOverrides.enableOutput = enableOutput;
end
services = lw.app.defaultServices(struct('carbide', carbideOverrides));
model = lw.app.Model(lw_hardware_config(), state, services);
model.Figure = ValueBox(true);

ports = struct( ...
    'appendUnit', @(value, ~) value, ...
    'logMessage', @(message) recordMessage(messages, message), ...
    'reportError', @(varargin) [], ...
    'runUiAction', @(actionFcn, ~) actionFcn(), ...
    'syncAll', @() [], ...
    'syncControlEnableStates', @() [], ...
    'syncStatusLabels', @() []);
controller = lw.app.CarbideController(model, ports);
end

function basic = basicWithNestedPoll(~, controllerBox, requestCount)
requestCount.Value = requestCount.Value + 1;
controllerBox.Value.onCarbideStatusTimer([], []);
basic = validBasic();
end

function basic = countedBasic(requestCount)
requestCount.Value = requestCount.Value + 1;
basic = validBasic();
end

function writeWithNestedPoll(controllerBox, writeCount)
writeCount.Value = writeCount.Value + 1;
controllerBox.Value.onCarbideStatusTimer([], []);
end

function basic = failOnceThenReturnBasic(requestCount)
requestCount.Value = requestCount.Value + 1;
if requestCount.Value == 1
    error('test:CarbideFailure', 'Synthetic Carbide request failure.');
end
basic = validBasic();
end

function basic = validBasic()
basic = struct( ...
    'ActualOutputPower', 1, ...
    'ActualPpDivider', 100, ...
    'ActualOutputFrequency', 1, ...
    'ActualPulseDuration', 250);
end

function recordMessage(messages, message)
messages.Value(end + 1) = string(message);
end
