classdef TestSafetyCoordinator < matlab.unittest.TestCase
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
        function stopUsesSafeOrderAndClearsPause(testCase)
            [coordinator, calls, model] = makeCoordinator();
            model.State.isBusy = true;
            model.State.isPaused = true;
            model.State.pauseRequested = true;
            model.State.resumeContext = struct('kind', "point");
            model.PausedManualMotionActive = true;

            coordinator.requestStop();

            testCase.verifyTrue(model.State.stopRequested);
            testCase.verifyFalse(model.State.pauseRequested);
            testCase.verifyFalse(model.State.isPaused);
            testCase.verifyEmpty(model.State.resumeContext);
            testCase.verifyFalse(model.PausedManualMotionActive);
            testCase.verifyEqual(calls.Value, [ ...
                "stopFlirLive:false", "requestStageStop", "forceLaserSafeOff", ...
                "stopFlirAcquisition", "updateStopStatus:true:true", "syncAll"]);
        end

        function requestStopContinuesAfterEveryFailure(testCase)
            expected = [ ...
                "stopFlirLive:false", "requestStageStop", "forceLaserSafeOff", ...
                "stopFlirAcquisition", "updateStopStatus:true:true", "syncAll"];
            for failingCall = expected
                [coordinator, calls, model] = makeCoordinator(failingCall);
                model.State.isBusy = true;
                model.State.isPaused = true;

                coordinator.requestStop();

                testCase.verifyEqual(calls.Value, expected, ...
                    sprintf('Cleanup stopped after injected failure in %s.', failingCall));
            end
        end

        function shutdownContinuesAfterEveryFailureAndIsIdempotent(testCase)
            expected = [ ...
                "stopFlirLive:false", "requestStageStop", "forceLaserSafeOff", ...
                "stopFlirAcquisition", "deleteFlirLive", "stopPositionTimer", "stopCarbideTimer", ...
                "closeSlmWindow", "disconnectBatchSlm", "shutdownMako", ...
                "finalizeRunLog", "disconnectAll", "deleteFigure"];
            for failingCall = expected
                [coordinator, calls] = makeCoordinator(failingCall);

                coordinator.shutdown();
                coordinator.shutdown();

                testCase.verifyEqual(calls.Value, expected, ...
                    sprintf('Shutdown stopped after injected failure in %s.', failingCall));
            end
        end
    end
end

function [coordinator, calls, model] = makeCoordinator(failingPort)
if nargin < 1
    failingPort = "";
end

config = lw_hardware_config();
model = lw.app.Model(config, lw_default_state());
calls = ValueBox(strings(1, 0));
ports = struct();
ports.stopFlirLive = @(enabled) record("stopFlirLive:" + string(enabled));
ports.deleteFlirLive = @() record("deleteFlirLive");
ports.stopPositionTimer = @() record("stopPositionTimer");
ports.requestStageStop = @() record("requestStageStop");
ports.forceLaserSafeOff = @() record("forceLaserSafeOff");
ports.stopFlirAcquisition = @() record("stopFlirAcquisition");
ports.stopCarbideTimer = @() record("stopCarbideTimer");
ports.closeSlmWindow = @() record("closeSlmWindow");
ports.disconnectBatchSlm = @() record("disconnectBatchSlm");
ports.shutdownMako = @() record("shutdownMako");
ports.finalizeRunLog = @() record("finalizeRunLog");
ports.disconnectAll = @() record("disconnectAll");
ports.deleteFigure = @() record("deleteFigure");
ports.updateStopStatus = @(wasPaused, wasBusy) record( ...
    "updateStopStatus:" + string(wasPaused) + ":" + string(wasBusy));
ports.syncAll = @() record("syncAll");
coordinator = lw.app.SafetyCoordinator(model, ports);

    function record(name)
        calls.Value(end + 1) = name;
        if name == failingPort
            error('Test:InjectedFailure', 'Injected failure for %s.', name);
        end
    end
end
