classdef TestSlmTab < matlab.unittest.TestCase
    %TESTSLMTAB SLM Control embedded in the main app's SLM tab.

    % These tests never press Connect or Show: the app re-adds its own folders
    % to the top of the path at launch, so fakes cannot reliably shadow the
    % SLM driver, and a test that reached it would drive the real PLUTO.
    properties (Constant, Access = private)
        SnapshotKey = 'LaserWritingCurrentSlmDrillOptions'
    end

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

    methods (TestMethodSetup)
        function clearSnapshot(testCase)
            keys = {testCase.SnapshotKey};
            removeAppData(keys);
            testCase.addTeardown(@() removeAppData(keys));
        end
    end

    methods (Test)
        function slmControlIsBuiltInTheSlmTab(testCase)
            figuresBefore = findall(groot, 'Type', 'figure');
            fig = testCase.openApp();

            slmTab = findall(fig, 'Type', 'uitab', 'Title', 'SLM');
            testCase.verifyNumElements(findall(slmTab, 'Type', 'uibutton', 'Text', 'Connect SLM'), 1);
            testCase.verifyNumElements(findall(slmTab, 'Type', 'uitab', 'Title', 'Global Adjustments'), 1);
            testCase.verifyEmpty(findall(fig, 'Type', 'uibutton', 'Text', 'Open SLM Control'));
            testCase.verifyNumElements(findall(groot, 'Type', 'figure'), numel(figuresBefore) + 1);
        end

        function arrowKeysNudgeOnlyWhileGlobalAdjustmentsAreShown(testCase)
            fig = testCase.openApp();
            [field, slider] = globalControl(fig, 'Pattern X offset px (+right)');
            startValue = field.Value;
            slider.ValueChangingFcn(slider, struct('Value', startValue));

            selectTab(fig, 'SLM');
            selectTab(fig, 'Main');
            pressRightArrow(fig);
            testCase.verifyEqual([field.Value, slider.Value], [startValue, startValue]);

            selectTab(fig, 'Global Adjustments');
            selectTab(fig, 'Control');
            pressRightArrow(fig);
            testCase.verifyEqual([field.Value, slider.Value], [startValue, startValue]);

            selectTab(fig, 'SLM');
            pressRightArrow(fig);
            testCase.verifyEqual([field.Value, slider.Value], [startValue, startValue] + 1);
        end

        function clickOutsideTheRowsDisarmsArrowKeys(testCase)
            fig = testCase.openApp();
            [field, slider] = globalControl(fig, 'Pattern X offset px (+right)');
            startValue = field.Value;
            logArea = appModel(fig).Ui.LogTextArea;
            selectTab(fig, 'SLM');
            selectTab(fig, 'Global Adjustments');
            slider.ValueChangingFcn(slider, struct('Value', startValue));

            click(fig, logArea);
            pressRightArrow(fig);
            testCase.verifyEqual(field.Value, startValue);

            click(fig, field);
            pressRightArrow(fig);
            testCase.verifyEqual(field.Value, startValue + 1);

            % A value typed into the field commits after the click that leaves it.
            click(fig, logArea);
            setField(field, startValue + 5);
            pressRightArrow(fig);
            testCase.verifyEqual(field.Value, startValue + 5);
        end

        function startupRemovesOnlyAStaleSlmTabSnapshot(testCase)
            setappdata(0, testCase.SnapshotKey, snapshotFrom("laser-writing-embedded-slm"));
            fig = testCase.openApp();
            testCase.verifyFalse(isappdata(0, testCase.SnapshotKey));
            close(fig);
            drawnow;

            batchSnapshot = snapshotFrom("laser-writing-batch-slm");
            setappdata(0, testCase.SnapshotKey, batchSnapshot);
            fig = testCase.openApp();
            setField(globalControl(fig, 'Pattern X offset px (+right)'), 3);
            testCase.verifyEqual(getappdata(0, testCase.SnapshotKey), batchSnapshot);
        end

        function disconnectedPreviewPublishesNoSnapshot(testCase)
            fig = testCase.openApp();

            slmTab = findall(fig, 'Type', 'uitab', 'Title', 'SLM');
            actions = findall(slmTab, 'Type', 'uipanel', 'Title', 'Actions');
            press(findall(actions, 'Type', 'uibutton', 'Text', 'Preview'));

            testCase.verifyFalse(isappdata(0, testCase.SnapshotKey));
        end

        function closeAndDeleteBothRemoveTheSnapshot(testCase)
            fig = testCase.openApp();
            setappdata(0, testCase.SnapshotKey, snapshotFrom("laser-writing-batch-slm"));
            close(fig);
            drawnow;
            testCase.verifyFalse(isappdata(0, testCase.SnapshotKey));

            fig = testCase.openApp();
            setappdata(0, testCase.SnapshotKey, snapshotFrom("laser-writing-batch-slm"));
            delete(fig);
            drawnow;
            testCase.verifyFalse(isappdata(0, testCase.SnapshotKey));
        end

        function confirmationsWaitWhileHardwareIsActive(testCase)
            calls = ValueBox(strings(1, 0));
            duringMove = ValueBox(@() []);
            fig = testCase.openApp(struct( ...
                'dialog', struct( ...
                    'alert', @(varargin) recordAlert(calls, varargin{:}), ...
                    'confirm', @(varargin) recordConfirm(calls)), ...
                'stage', fakeStageServices(duringMove)));
            reset = slmButton(fig, 'Reset');
            model = appModel(fig);

            for flag = {'isBusy', 'isPaused', 'laserIsOn'}
                model.State.(flag{1}) = true;
                press(reset);
                model.State.(flag{1}) = false;
            end
            model.PausedManualMotionActive = true;
            press(reset);
            model.PausedManualMotionActive = false;

            model.State.axes = struct('x', 1, 'y', 1, 'z', 1);
            duringMove.Value = @() press(reset);
            press(model.Ui.JogXPlusButton);
            testCase.verifyFalse(model.ManualStageMoveActive);
            press(reset);

            testCase.verifyEqual(calls.Value, [repmat("alert:modal=false", 1, 5), "confirm"]);
        end
    end

    methods (Access = private)
        function fig = openApp(testCase, serviceOverrides)
            if nargin < 2
                serviceOverrides = struct();
            end
            fig = laser_writing_app_refactored(serviceOverrides);
            testCase.addTeardown(@() closeIfValid(fig));
            drawnow;
        end
    end
end

function model = appModel(fig)
controller = getappdata(fig, 'LaserWritingAppController');
model = controller.Model;
end

function selectTab(fig, title)
tab = findall(fig, 'Type', 'uitab', 'Title', title);
tab.Parent.SelectedTab = tab;
drawnow;
end

function button = slmButton(fig, text)
slmTab = findall(fig, 'Type', 'uitab', 'Title', 'SLM');
button = findall(slmTab, 'Type', 'uibutton', 'Text', text);
end

function press(button)
button.ButtonPushedFcn(button, []);
drawnow;
end

function click(fig, component)
fig.CurrentObject = component;
fig.WindowButtonDownFcn(fig, []);
end

function pressRightArrow(fig)
fig.WindowKeyPressFcn(fig, struct('Key', 'rightarrow'));
end

function [field, slider] = globalControl(fig, labelText)
label = findall(fig, 'Type', 'uilabel', 'Text', labelText);
field = [];
slider = [];
for control = reshape(label.Parent.Children, 1, [])
    if ~isequal(control.Layout.Row, label.Layout.Row)
        continue;
    end
    if isa(control, 'matlab.ui.control.NumericEditField')
        field = control;
    elseif isa(control, 'matlab.ui.control.Slider')
        slider = control;
    end
end
end

function setField(field, value)
field.Value = value;
field.ValueChangedFcn(field, []);
drawnow;
end

function snapshot = snapshotFrom(source)
snapshot = struct('source', source, 'options', struct('vortexCharge', 1), 'currentOnSlm', "row");
end

function removeAppData(keys)
for index = 1:numel(keys)
    if isappdata(0, keys{index})
        rmappdata(0, keys{index});
    end
end
end

function services = fakeStageServices(duringMove)
services = struct( ...
    'getPosition', @(~) struct('x', 75, 'y', 12.5, 'z', 75), ...
    'moveAbsolute', @(state, target, ~, ~) moveWhile(duringMove, state, target), ...
    'stop', @(~) [], ...
    'setPulseTrigger', @(~, ~, ~) [], ...
    'disconnectAll', @(state, ~) clearFakeAxes(state));
end

function [state, wasStopped] = moveWhile(duringMove, state, target)
feval(duringMove.Value);
state.currentPosition = target;
wasStopped = false;
end

function state = clearFakeAxes(state)
state.axes = struct('x', [], 'y', [], 'z', []);
end

function recordAlert(calls, varargin)
modal = true;
index = find(cellfun(@(value) isequal(value, 'Modal'), varargin), 1);
if ~isempty(index)
    modal = varargin{index + 1};
end
calls.Value(end + 1) = "alert:modal=" + string(modal);
end

function choice = recordConfirm(calls)
calls.Value(end + 1) = "confirm";
choice = 'Cancel';
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
