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
        function connectionInitializesInactiveGate(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            timerCleanup = onCleanup(@() controller.StageLaser.stopPositionTimer());
            controller.Model.Services.stage.connect = ...
                @(state, ~) recordConnection(calls, state);
            controller.Model.State.currentPosition = struct('x', 1, 'y', 2, 'z', 3);
            controller.Model.State.laserIsOn = true;

            controller.StageLaser.connectStagesImpl();

            testCase.verifyEqual(calls.Value, ["connect", "trigger:false"]);
            testCase.verifyFalse(controller.Model.State.laserIsOn);
        end

        function connectionFailsIfInactiveGateCannotBeWritten(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            controller.Model.Services.stage.connect = ...
                @(state, ~) recordConnection(calls, state);
            controller.Model.Services.stage.setPulseTrigger = ...
                @(~, ~, ~) error('Test:GateWriteFailure', 'Injected gate write failure.');
            controller.Model.State.laserIsOn = true;

            testCase.verifyError(@() controller.StageLaser.connectStagesImpl(), ...
                'Test:GateWriteFailure');

            testCase.verifyEqual(calls.Value, "connect");
            testCase.verifyTrue(controller.Model.State.laserIsOn);
            testCase.verifyEmpty(controller.Model.Ui.PositionTimerHandle);
        end

        function recoveryConnectionInitializesInactiveGate(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            timerCleanup = onCleanup(@() controller.StageLaser.stopPositionTimer());
            controller.Model.Services.stage.connect = ...
                @(state, ~) recordConnection(calls, state);
            controller.Model.State.laserIsOn = true;

            connected = controller.Run.reconnectStagesForRecovery();

            testCase.verifyTrue(connected);
            testCase.verifyEqual(calls.Value, ["connect", "trigger:false"]);
            testCase.verifyFalse(controller.Model.State.laserIsOn);
        end

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

        function appliedPowerChangesOnlyWhenDaqIsWritten(testCase)
            [fig, controller, ~] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            ui = controller.Model.Ui;
            testCase.verifyEqual(ui.AppliedLaserPowerLabel.Text, '-');

            controller.Model.State.laserPowerPercent = 0;
            ui.LaserPowerField.Value = 2;
            controller.UiPolicy.syncAll();
            testCase.verifyEqual(ui.AppliedLaserPowerLabel.Text, '0 %');

            controller.StageLaser.onApplyManualPower([], []);
            testCase.verifyEqual(ui.AppliedLaserPowerLabel.Text, '2 %');

            controller.StageLaser.forceLaserSafeOff();
            controller.UiPolicy.syncAll();
            testCase.verifyEqual(ui.AppliedLaserPowerLabel.Text, '0 %');
        end

        function appliedPowerShowsExposurePowerUntilSafeOff(testCase)
            [fig, controller, ~] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            label = controller.Model.Ui.AppliedLaserPowerLabel;
            seen = ValueBox(strings(1, 0));
            controller.Model.Services.laser.manualExposure = ...
                @(varargin) recordLabelDuringExposure(seen, label);
            controller.Model.State.laserPowerPercent = 2;
            controller.Model.Ui.ExposureTimeField.Value = 1e6;
            controller.Model.Ui.ExposureRepeatField.Value = 1;
            controller.Model.Ui.ExposureIntervalField.Value = 0;
            controller.Model.Ui.PreviewPowerField.Value = 37;

            controller.StageLaser.fireExposureImpl();

            testCase.verifyEqual(seen.Value, "37 %");
            testCase.verifyEqual(label.Text, '0 %');
        end

        function planRunMarksAppliedPowerUnknown(testCase)
            [fig, controller, ~] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            label = controller.Model.Ui.AppliedLaserPowerLabel;
            seen = ValueBox(strings(1, 0));
            controller.Model.Services.execution.runPoint = ...
                @(state, ~, ~, options) fakeRunPoint(seen, label, state, options);
            controller.Model.State.laserPowerPercent = 2;
            preflight = struct('trajectory', struct('x', 0), 'motion', struct());

            controller.Run.executeRunSnapshot("Point Mode", preflight, []);

            testCase.verifyEqual(seen.Value, "-");
            testCase.verifyTrue(isnan(controller.Model.State.laserPowerPercent));
        end

        function zSweepRecoveryRetryKeepsAppliedPowerUnknown(testCase)
            [fig, controller, calls] = makeController();
            cleanup = onCleanup(@() deleteIfValid(fig));
            timerCleanup = onCleanup(@() controller.StageLaser.stopPositionTimer());
            label = controller.Model.Ui.AppliedLaserPowerLabel;
            seen = ValueBox(strings(1, 0));
            attempts = ValueBox(0);
            center = controller.Model.Config.motion.centerPosition;
            controller.Model.Services.stage.connect = ...
                @(state, ~) recordConnection(calls, state);
            controller.Model.Services.stage.stop = @(~) [];
            controller.Model.Services.stage.moveAbsolute = @(state, ~, ~, ~) deal(state, false);
            controller.Model.Services.execution.runZSweep = ...
                @(state, ~, ~, options) fakeRecoveringZSweep( ...
                    attempts, seen, label, state, options, center);
            controller.Model.State.currentPosition = center;
            sweep = struct('x', center.x, 'displayY', 0, 'powerPercent', 10, ...
                'sweepSpeedMmPerSecond', 1, 'returnSpeedMmPerSecond', 1, ...
                'repeatCount', 1, 'exposureDirection', "Back -> Front", ...
                'preMoveMotion', struct());
            preflight = struct('sweepJobs', struct('sweep', sweep), 'progressTotal', 3);
            options = struct( ...
                'shouldStopFcn', @() false, ...
                'pauseRequestedFcn', @() false, ...
                'laserStateFcn', @(isOn) controller.StageLaser.setLaserState(isOn));

            controller.Run.runZSweepJobs(preflight, options, []);

            testCase.verifyEqual(attempts.Value, 2);
            testCase.verifyEqual(seen.Value, "-");
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

function state = recordConnection(calls, state)
calls.Value(end + 1) = "connect";
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

function wasStopped = recordLabelDuringExposure(seen, label)
seen.Value(end + 1) = string(label.Text);
wasStopped = false;
end

function [state, result] = fakeRunPoint(seen, label, state, options)
options.laserStateFcn(true);
seen.Value(end + 1) = string(label.Text);
options.laserStateFcn(false);
result = struct('status', "finished", 'returnTarget', state.currentPosition);
end

function [state, result] = fakeRecoveringZSweep(attempts, seen, label, state, options, target)
attempts.Value = attempts.Value + 1;
if attempts.Value == 1
    result = struct('status', "hardware_error", 'nextStepIndex', 1, ...
        'returnTarget', target, 'errorMessage', "Injected Zaber error");
    return;
end
options.laserStateFcn(true);
seen.Value(end + 1) = string(label.Text);
options.laserStateFcn(false);
result = struct('status', "finished", 'nextStepIndex', 1, 'returnTarget', target);
end

function deleteIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    delete(fig);
end
end
