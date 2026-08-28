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
    end
end

function [fig, controller, calls] = makeController()
calls = ValueBox(strings(1, 0));
overrides = struct( ...
    'stage', struct('setPulseTrigger', @(~, active, ~) recordTrigger(calls, active)), ...
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

function deleteIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    delete(fig);
end
end
