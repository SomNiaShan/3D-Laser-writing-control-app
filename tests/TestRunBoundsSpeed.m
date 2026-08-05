classdef TestRunBoundsSpeed < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
            helperPath = fullfile(projectRoot, 'tests', 'helpers');
            addpath(helperPath);
            testCase.addTeardown(@() rmpath(helperPath));
        end
    end

    methods (Test)
        function checkBoundsUsesPromptedSpeedForEveryAxis(testCase)
            recorder = ValueBox(defaultRecorder({'2.5'}));
            fig = laser_writing_app_refactored(boundsSpeedServices(recorder));
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;

            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;
            connectFakeStages(model, recorder.Value.position);
            prepareTestPlan(model);
            model.Ui.AbsoluteVelXField.Value = 80;
            model.Ui.AbsoluteVelYField.Value = 70;
            model.Ui.AbsoluteVelZField.Value = 60;
            controller.UiPolicy.syncAll();

            testCase.verifyEqual(model.Ui.StartRunButton.Text, 'Run Plan');
            testCase.verifyEqual(model.Ui.StartRunButton.BackgroundColor, ...
                [0.20, 0.70, 0.30], 'AbsTol', 1e-12);
            testCase.verifyEqual(model.Ui.StartRunButton.FontColor, [1, 1, 1]);
            testCase.verifyEqual(model.Ui.StartRunButton.FontWeight, 'bold');

            controller.Run.checkBoundsImpl();

            testCase.verifyNumElements(recorder.Value.prompts, 1);
            promptArgs = recorder.Value.prompts{1};
            testCase.verifyEqual(string(promptArgs{1}), "Move speed (mm/s):");
            testCase.verifyEqual(string(promptArgs{2}), "Check Bounds Move Speed");
            testCase.verifyEqual(string(promptArgs{4}), "10");

            testCase.verifyNumElements(recorder.Value.confirmations, 1);
            confirmationArgs = recorder.Value.confirmations{1};
            testCase.verifySubstring(string(confirmationArgs{2}), "at 2.5 mm/s?");
            testCase.verifyNumElements(recorder.Value.motions, 8);
            for index = 1:numel(recorder.Value.motions)
                testCase.verifyEqual(recorder.Value.motions{index}.velocity, ...
                    struct('x', 2.5, 'y', 2.5, 'z', 2.5));
                testCase.verifyEqual(recorder.Value.motions{index}.acceleration, ...
                    struct('x', 100, 'y', 100, 'z', 100));
            end
        end

        function cancellingSpeedPromptDoesNotMove(testCase)
            recorder = ValueBox(defaultRecorder({}));
            fig = laser_writing_app_refactored(boundsSpeedServices(recorder));
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;

            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;
            connectFakeStages(model, recorder.Value.position);
            prepareTestPlan(model);

            controller.Run.checkBoundsImpl();

            testCase.verifyNumElements(recorder.Value.prompts, 1);
            testCase.verifyEmpty(recorder.Value.confirmations);
            testCase.verifyEmpty(recorder.Value.motions);
            testCase.verifyFalse(model.State.isBusy);
        end

        function invalidSpeedIsRejectedBeforeConfirmationOrMotion(testCase)
            recorder = ValueBox(defaultRecorder({'0'}));
            fig = laser_writing_app_refactored(boundsSpeedServices(recorder));
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;

            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;
            connectFakeStages(model, recorder.Value.position);
            prepareTestPlan(model);

            caughtMessage = "";
            try
                controller.Run.checkBoundsImpl();
            catch ME
                caughtMessage = string(ME.message);
            end

            testCase.verifyEqual(caughtMessage, ...
                "Check Bounds move speed must be a positive number.");
            testCase.verifyEmpty(recorder.Value.confirmations);
            testCase.verifyEmpty(recorder.Value.motions);
            testCase.verifyFalse(model.State.isBusy);
        end
    end
end

function value = defaultRecorder(promptAnswer)
value = struct( ...
    'position', struct('x', 15, 'y', 10, 'z', 35), ...
    'promptAnswer', {promptAnswer}, ...
    'confirmationChoice', "Move Corners", ...
    'prompts', {cell(1, 0)}, ...
    'confirmations', {cell(1, 0)}, ...
    'targets', {cell(1, 0)}, ...
    'motions', {cell(1, 0)});
end

function overrides = boundsSpeedServices(recorder)
overrides = struct( ...
    'stage', struct( ...
        'getPosition', @(~) recorder.Value.position, ...
        'moveAbsolute', @(state, target, motion, ~) ...
            recordMove(recorder, state, target, motion), ...
        'stop', @(~) [], ...
        'setPulseTrigger', @(~, ~, ~) [], ...
        'disconnectAll', @(state, ~) clearFakeAxes(state)), ...
    'dialog', struct( ...
        'alert', @(varargin) [], ...
        'confirm', @(varargin) recordConfirmation(recorder, varargin{:}), ...
        'prompt', @(varargin) recordPrompt(recorder, varargin{:})));
end

function connectFakeStages(model, position)
model.State.axes = struct('x', 1, 'y', 1, 'z', 1);
model.State.currentPosition = position;
end

function prepareTestPlan(model)
trajectory = lw_make_trajectory( ...
    [10; 20], [5; 15], [30; 40], [0; 0], ...
    "bounds_speed_test", "point", struct('powerSource', "fixed"));
model.PreparedPlan = struct( ...
    'kind', "point", ...
    'sourceType', "bounds_speed_test", ...
    'trajectory', trajectory);
model.TrajectoryInputsDirty = false;
end

function answer = recordPrompt(recorder, varargin)
value = recorder.Value;
value.prompts{end + 1} = varargin;
answer = value.promptAnswer;
recorder.Value = value;
end

function choice = recordConfirmation(recorder, varargin)
value = recorder.Value;
value.confirmations{end + 1} = varargin;
choice = value.confirmationChoice;
recorder.Value = value;
end

function [state, wasStopped] = recordMove(recorder, state, target, motion)
value = recorder.Value;
value.targets{end + 1} = target;
value.motions{end + 1} = motion;
value.position = target;
recorder.Value = value;
state.currentPosition = target;
wasStopped = false;
end

function state = clearFakeAxes(state)
state.axes = struct('x', [], 'y', [], 'z', []);
end

function deleteIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
