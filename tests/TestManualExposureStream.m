classdef TestManualExposureStream < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(~)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function oneSecondPatternHasExpectedHardwareTimeline(testCase)
            plan = lw_manual_exposure_stream_plan(1, 2, 1, lw_hardware_config());

            testCase.verifyEqual(plan.exposureUs, 1e6);
            testCase.verifyEqual(plan.cycleWaitMilliseconds, 2000);
            testCase.verifyEqual(plan.finalWaitMilliseconds, 1000);
            testCase.verifyEqual(plan.expectedOpticalDurationSeconds, 3);
            testCase.verifyEqual(plan.expectedStreamBusySeconds, 3);
        end

        function subMillisecondPulseCanUseComplementaryGap(testCase)
            plan = lw_manual_exposure_stream_plan(100e-6, 3, 900e-6, lw_hardware_config());

            testCase.verifyEqual(plan.exposureUs, 100);
            testCase.verifyEqual(plan.intervalUs, 900);
            testCase.verifyEqual(plan.cycleWaitMilliseconds, 1);
            testCase.verifyEqual(plan.expectedOpticalDurationSeconds, 2.1e-3, ...
                'AbsTol', 1e-12);
        end

        function singleShortPulseDoesNotNeedRepeatCycle(testCase)
            plan = lw_manual_exposure_stream_plan(100e-6, 1, 0.123456, lw_hardware_config());

            testCase.verifyEmpty(plan.cycleWaitMilliseconds);
            testCase.verifyEqual(plan.finalWaitMilliseconds, 1);
            testCase.verifyEqual(plan.expectedOpticalDurationSeconds, 100e-6, ...
                'AbsTol', 1e-12);
        end

        function unrepresentableRepeatCycleIsRejectedWithoutRounding(testCase)
            testCase.verifyError(@() lw_manual_exposure_stream_plan( ...
                100e-6, 2, 0.1, lw_hardware_config()), ...
                'lw:stage:StreamCycleResolution');
        end

        function tooShortRepeatCycleIsRejected(testCase)
            testCase.verifyError(@() lw_manual_exposure_stream_plan( ...
                100e-6, 2, 0, lw_hardware_config()), ...
                'lw:stage:StreamCycleBelowMinimum');
        end

        function productionUsesStoredScheduledOutputs(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceText = fileread(fullfile(projectRoot, 'src', 'hardware', ...
                'lw_manual_exposure_stream.m'));

            testCase.verifyNotEmpty(strfind(sourceText, 'setupStore'));
            testCase.verifyNotEmpty(strfind(sourceText, 'setDigitalOutputSchedule'));
            testCase.verifyNotEmpty(strfind(sourceText, 'setupLive'));
            testCase.verifyNotEmpty(strfind(sourceText, 'streamHandle.call'));
        end

        function emergencyCleanupStopsStreamBeforeForcingOutputsOff(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceText = fileread(fullfile(projectRoot, 'src', 'hardware', ...
                'lw_manual_exposure_stream.m'));
            cleanupStart = strfind(sourceText, 'function localSafeCleanup');
            cleanupText = sourceText(cleanupStart(1):end);

            stopIndex = strfind(cleanupText, 'lw_stop_motion(state)');
            triggerOffIndex = strfind(cleanupText, 'lw_set_stage_pulse_trigger(state, false');
            daqOffIndex = strfind(cleanupText, 'lw_set_laser_power(state, 0)');
            testCase.verifyLessThan(stopIndex(1), triggerOffIndex(1));
            testCase.verifyLessThan(triggerOffIndex(1), daqOffIndex(1));
        end
    end
end
