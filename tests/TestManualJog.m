classdef TestManualJog < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            projectRoot = refactorRoot;
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
            helperPath = fullfile(refactorRoot, 'tests', 'helpers');
            addpath(helperPath);
            testCase.addTeardown(@() rmpath(helperPath));
        end
    end

    methods (Test)
        function allJogButtonsDispatchExpectedStageTargets(testCase)
            recorder = ValueBox(struct( ...
                'position', struct('x', 75, 'y', 12.5, 'z', 75), ...
                'targets', {cell(1, 0)}, ...
                'motions', {cell(1, 0)}));
            overrides = manualJogServices(recorder);

            fig = laser_writing_app_refactored(overrides);
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;
            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;
            model.State.axes = struct('x', 1, 'y', 1, 'z', 1);
            controller.UiPolicy.syncAll();

            testCase.verifyEqual([model.Ui.ManualVelXField.Value, ...
                model.Ui.ManualVelYField.Value, model.Ui.ManualVelZField.Value], [10, 10, 10]);
            testCase.verifyEqual([model.Ui.ManualAccXField.Value, ...
                model.Ui.ManualAccYField.Value, model.Ui.ManualAccZField.Value], [100, 100, 100]);

            startPosition = recorder.Value.position;
            step = 0.01;
            cases = { ...
                model.Ui.JogXPlusButton,  struct('x', +step, 'y', 0, 'z', 0); ...
                model.Ui.JogXMinusButton, struct('x', -step, 'y', 0, 'z', 0); ...
                model.Ui.JogYPlusButton,  struct('x', 0, 'y', -step, 'z', 0); ...
                model.Ui.JogYMinusButton, struct('x', 0, 'y', +step, 'z', 0); ...
                model.Ui.JogZPlusButton,  struct('x', 0, 'y', 0, 'z', +step); ...
                model.Ui.JogZMinusButton, struct('x', 0, 'y', 0, 'z', -step)};

            for caseIndex = 1:size(cases, 1)
                resetRecorderPosition(recorder, startPosition);
                invokeButton(cases{caseIndex, 1});
                expectedOffset = cases{caseIndex, 2};
                expectedTarget = struct( ...
                    'x', startPosition.x + expectedOffset.x, ...
                    'y', startPosition.y + expectedOffset.y, ...
                    'z', startPosition.z + expectedOffset.z);
                testCase.verifyEqual(recorder.Value.targets{caseIndex}, expectedTarget, ...
                    'AbsTol', 1e-12);
            end

            testCase.verifyNumElements(recorder.Value.targets, 6);
            testCase.verifyNumElements(recorder.Value.motions, 6);
            for motionIndex = 1:numel(recorder.Value.motions)
                motion = recorder.Value.motions{motionIndex};
                testCase.verifyEqual(motion.velocity, struct('x', 10, 'y', 10, 'z', 10));
                testCase.verifyEqual(motion.acceleration, struct('x', 100, 'y', 100, 'z', 100));
            end
        end
    end
end

function overrides = manualJogServices(recorder)
overrides = struct( ...
    'stage', struct( ...
        'getPosition', @(~) recorder.Value.position, ...
        'moveAbsolute', @(state, target, motion, ~) recordMove(recorder, state, target, motion), ...
        'stop', @(~) [], ...
        'setPulseTrigger', @(~, ~, ~) [], ...
        'disconnectAll', @(state, ~) clearFakeAxes(state)), ...
    'dialog', struct('alert', @(varargin) []));
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

function resetRecorderPosition(recorder, position)
value = recorder.Value;
value.position = position;
recorder.Value = value;
end

function state = clearFakeAxes(state)
state.axes = struct('x', [], 'y', [], 'z', []);
end

function invokeButton(button)
callback = button.ButtonPushedFcn;
callback(button, []);
drawnow;
end

function deleteIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    delete(fig);
end
end
