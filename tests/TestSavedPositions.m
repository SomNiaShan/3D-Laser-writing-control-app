classdef TestSavedPositions < matlab.unittest.TestCase
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
        function savesAndMovesToFourIndependentPositionSlots(testCase)
            recorder = ValueBox(struct( ...
                'position', struct('x', 21.849, 'y', 7.7, 'z', 66.203), ...
                'targets', {cell(1, 0)}, ...
                'motions', {cell(1, 0)}, ...
                'confirmationChoice', "Update", ...
                'confirmations', {cell(1, 0)}));
            overrides = savedPositionServices(recorder);

            fig = laser_writing_app_refactored(overrides);
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;
            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;
            model.State.axes = struct('x', 1, 'y', 1, 'z', 1);
            controller.UiPolicy.syncAll();

            testCase.verifyEqual([model.Ui.AbsoluteVelXField.Value, ...
                model.Ui.AbsoluteVelYField.Value, model.Ui.AbsoluteVelZField.Value], [10, 10, 10]);
            testCase.verifyEqual([model.Ui.AbsoluteAccXField.Value, ...
                model.Ui.AbsoluteAccYField.Value, model.Ui.AbsoluteAccZField.Value], [100, 100, 100]);

            for positionIndex = 1:4
                testCase.verifyEqual(string(model.Ui.(sprintf('SavePosition%dButton', positionIndex)).Enable), "on");
                testCase.verifyEqual(string(model.Ui.(sprintf('MoveToPosition%dButton', positionIndex)).Enable), "off");
            end

            savedPositions = [ ...
                struct('x', 21.849, 'y', 7.7, 'z', 66.203), ...
                struct('x', 22.5, 'y', 8.2, 'z', 67), ...
                struct('x', 30, 'y', 10, 'z', 70), ...
                struct('x', 45, 'y', 12, 'z', 80)];
            for positionIndex = 1:4
                setRecorderPosition(recorder, savedPositions(positionIndex));
                invokeButton(model.Ui.(sprintf('SavePosition%dButton', positionIndex)));
                testCase.verifyEqual(model.SavedStagePositions(positionIndex).x, savedPositions(positionIndex).x);
                testCase.verifyEqual(model.SavedStagePositions(positionIndex).y, savedPositions(positionIndex).y);
                testCase.verifyEqual(model.SavedStagePositions(positionIndex).z, savedPositions(positionIndex).z);
                testCase.verifyEqual(string(model.Ui.(sprintf('MoveToPosition%dButton', positionIndex)).Enable), "on");
            end

            testCase.verifyTrue(all([model.SavedStagePositions.isSet]));
            testCase.verifyEqual(model.Ui.SavePosition1Button.Text, 'Update 1');
            testCase.verifyEmpty(recorder.Value.targets);

            setRecorderPosition(recorder, struct('x', 30, 'y', 60, 'z', 40));
            invokeButton(model.Ui.MoveToPosition1Button);

            testCase.verifyNumElements(recorder.Value.targets, 1);
            testCase.verifyEqual(recorder.Value.targets{1}, savedPositions(1), 'AbsTol', 1e-12);
            testCase.verifyEqual(model.Ui.TargetXField.Value, savedPositions(1).x);
            testCase.verifyEqual(model.Ui.TargetYField.Value, ...
                model.Config.motion.yDisplayReference - savedPositions(1).y);
            testCase.verifyEqual(model.Ui.TargetZField.Value, savedPositions(1).z);
            testCase.verifyEqual(recorder.Value.motions{1}.velocity, ...
                struct('x', 10, 'y', 10, 'z', 10));
            testCase.verifyEqual(recorder.Value.motions{1}.acceleration, ...
                struct('x', 100, 'y', 100, 'z', 100));
        end

        function updatingPositionRequiresConfirmation(testCase)
            originalPosition = struct('x', 21.849, 'y', 7.7, 'z', 66.203);
            replacementPosition = struct('x', 30, 'y', 10, 'z', 40);
            recorder = ValueBox(struct( ...
                'position', originalPosition, ...
                'targets', {cell(1, 0)}, ...
                'motions', {cell(1, 0)}, ...
                'confirmationChoice', "Cancel", ...
                'confirmations', {cell(1, 0)}));

            fig = laser_writing_app_refactored(savedPositionServices(recorder));
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;
            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;
            model.State.axes = struct('x', 1, 'y', 1, 'z', 1);
            controller.UiPolicy.syncAll();

            invokeButton(model.Ui.SavePosition1Button);
            testCase.verifyEmpty(recorder.Value.confirmations, ...
                'Saving an unused slot should not require confirmation.');

            setRecorderPosition(recorder, replacementPosition);
            invokeButton(model.Ui.SavePosition1Button);
            testCase.verifyEqual(model.SavedStagePositions(1).x, originalPosition.x);
            testCase.verifyEqual(model.SavedStagePositions(1).y, originalPosition.y);
            testCase.verifyEqual(model.SavedStagePositions(1).z, originalPosition.z);
            testCase.verifyNumElements(recorder.Value.confirmations, 1);

            confirmationArgs = recorder.Value.confirmations{1};
            testCase.verifyEqual(string(confirmationArgs{3}), "Confirm Position Update");
            testCase.verifySubstring(string(confirmationArgs{2}), "Update saved position 1?");
            testCase.verifySubstring(string(confirmationArgs{2}), ...
                "Existing position: X 21.849, Y 17.300, Z 66.203 mm");
            testCase.verifyEqual(string(confirmationArgs{5}), ["Update", "Cancel"]);
            testCase.verifyEqual(string(confirmationArgs{7}), "Cancel");
            testCase.verifyEqual(string(confirmationArgs{9}), "Cancel");

            setConfirmationChoice(recorder, "Update");
            invokeButton(model.Ui.SavePosition1Button);
            testCase.verifyEqual(model.SavedStagePositions(1).x, replacementPosition.x);
            testCase.verifyEqual(model.SavedStagePositions(1).y, replacementPosition.y);
            testCase.verifyEqual(model.SavedStagePositions(1).z, replacementPosition.z);
            testCase.verifyNumElements(recorder.Value.confirmations, 2);
        end
    end
end

function overrides = savedPositionServices(recorder)
overrides = struct( ...
    'stage', struct( ...
        'getPosition', @(~) recorder.Value.position, ...
        'moveAbsolute', @(state, target, motion, ~) recordMove(recorder, state, target, motion), ...
        'stop', @(~) [], ...
        'setPulseTrigger', @(~, ~, ~) [], ...
        'disconnectAll', @(state, ~) clearFakeAxes(state)), ...
    'dialog', struct( ...
        'alert', @(varargin) [], ...
        'confirm', @(varargin) recordConfirmation(recorder, varargin{:})));
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

function setRecorderPosition(recorder, position)
value = recorder.Value;
value.position = position;
recorder.Value = value;
end

function setConfirmationChoice(recorder, choice)
value = recorder.Value;
value.confirmationChoice = string(choice);
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
    drawnow;
end
end
