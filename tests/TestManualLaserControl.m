classdef TestManualLaserControl < matlab.unittest.TestCase
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
        function manualOnOffOnlyChangePulseTrigger(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));

            controller.StageLaser.laserOnImpl();
            controller.StageLaser.laserOffImpl();

            testCase.verifyEqual(calls.Value, ["trigger:true", "trigger:false"]);
        end

        function manualPowerIsAppliedSeparately(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            controller.Model.Ui.LaserPowerField.Value = 37;

            controller.StageLaser.applyManualPowerImpl();

            testCase.verifyEqual(calls.Value, "power:37");
        end

        function forcedSafeOffStillClearsDaq(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));

            controller.StageLaser.forceLaserSafeOff();

            testCase.verifyEqual(calls.Value, ["trigger:false", "daq:0"]);
        end

        function originalManualExposureStillRunsOneHostCallPerRepeat(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            controller.Model.Services.laser.manualExposure = ...
                @(state, config, power, exposure, laserStateFcn, ...
                    shouldStopFcn, yieldFcn) ...
                fakeOriginalExposure(calls, state, config, power, exposure, ...
                    laserStateFcn, shouldStopFcn, yieldFcn);
            controller.Model.Ui.ExposureTimeField.Value = 1e6;
            controller.Model.Ui.ExposureRepeatField.Value = 2;
            controller.Model.Ui.ExposureIntervalField.Value = 0;
            controller.Model.Ui.PreviewPowerField.Value = 37;

            controller.StageLaser.fireExposureImpl();

            testCase.verifyEqual(calls.Value, [ ...
                "original:37:1", "original:37:1", "trigger:false", "daq:0"]);
            testCase.verifyEqual(controller.Model.RunProgressText, '2 / 2');
            testCase.verifyEqual(controller.Model.RunCurrentText, "Idle");
        end

        function streamManualExposureSubmitsOneCompleteSequence(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            controller.Model.Services.laser.manualExposureSequence = ...
                @(state, config, power, exposure, repeats, interval, laserStateFcn, ...
                    progressFcn, shouldStopFcn, yieldFcn) ...
                fakeSequence(calls, state, config, power, exposure, repeats, ...
                    interval, laserStateFcn, progressFcn, shouldStopFcn, yieldFcn);
            controller.Model.Ui.ExposureTimeField.Value = 1e6;
            controller.Model.Ui.ExposureRepeatField.Value = 2;
            controller.Model.Ui.ExposureIntervalField.Value = 1;
            controller.Model.Ui.PreviewPowerField.Value = 37;

            controller.StageLaser.fireStreamExposureImpl();

            testCase.verifyEqual(calls.Value, [ ...
                "sequence:37:1:2:1", "trigger:false", "daq:0"]);
            testCase.verifyEqual(controller.Model.RunProgressText, '2 / 2');
            testCase.verifyEqual(controller.Model.RunCurrentText, "Idle");
        end
    end
end

function [fig, controller, calls] = makeController()
calls = ValueBox(strings(1, 0));
overrides = struct( ...
    'stage', struct( ...
        'getPosition', @(state) state.currentPosition, ...
        'setPulseTrigger', @(~, active, ~) recordTrigger(calls, active)), ...
    'daq', struct('write', @(~, value) recordValue(calls, "daq", value)), ...
    'laser', struct('setPower', @(~, value) recordValue(calls, "power", value)));
fig = laser_writing_app_refactored(overrides);
drawnow;
controller = getappdata(fig, 'LaserWritingAppController');
controller.Model.State.axes = struct('x', 1, 'y', 1, 'z', 1);
controller.Model.State.daq = 1;
end

function recordTrigger(calls, active)
calls.Value(end + 1) = "trigger:" + string(logical(active));
end

function recordValue(calls, name, value)
calls.Value(end + 1) = name + ":" + string(value);
end

function [wasStopped, completedCount] = fakeSequence( ...
        calls, ~, ~, power, exposure, repeats, interval, laserStateFcn, ...
        progressFcn, shouldStopFcn, yieldFcn)
calls.Value(end + 1) = sprintf('sequence:%g:%g:%d:%g', ...
    power, exposure, repeats, interval);
yieldFcn();
wasStopped = shouldStopFcn();
if wasStopped
    completedCount = 0;
    return;
end
laserStateFcn(true);
progressFcn(repeats);
laserStateFcn(false);
completedCount = repeats;
end

function wasStopped = fakeOriginalExposure( ...
        calls, ~, ~, power, exposure, laserStateFcn, shouldStopFcn, yieldFcn)
calls.Value(end + 1) = sprintf('original:%g:%g', power, exposure);
yieldFcn();
wasStopped = shouldStopFcn();
if wasStopped
    return;
end
laserStateFcn(true);
laserStateFcn(false);
end

function deleteIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    delete(fig);
end
end
