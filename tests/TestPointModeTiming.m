classdef TestPointModeTiming < matlab.unittest.TestCase
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
        function writingPlanTimingOverridesUiDefaults(testCase)
            path = writePlan(testCase, [100e-6; 300e-6], [0.01; 0.02], ["point"; "point"]);
            trajectory = lw_import_writing_plan_table(path);

            [prepared, timing] = lw_prepare_point_run_trajectory( ...
                trajectory, 9, 8, lw_hardware_config());

            testCase.verifyEqual(prepared.dwellSeconds, [100e-6; 300e-6], 'AbsTol', 1e-12);
            testCase.verifyEqual(prepared.preWritePauseSeconds, [0.01; 0.02]);
            testCase.verifyEqual(timing.executionMode, "timed_dwell");
            testCase.verifyEqual(timing.source, "writing_plan");
            testCase.verifyEqual(timing.dwellMicrosecondsMin, 100);
            testCase.verifyEqual(timing.dwellMicrosecondsMax, 300);
            testCase.verifyEqual(timing.preWritePauseSecondsMin, 0.01);
            testCase.verifyEqual(timing.preWritePauseSecondsMax, 0.02);
        end

        function tooShortWritingPlanDwellIsRejected(testCase)
            path = writePlan(testCase, 1e-6, 0, "point");
            trajectory = lw_import_writing_plan_table(path);

            testCase.verifyError(@() lw_prepare_point_run_trajectory( ...
                trajectory, 100e-6, 0, lw_hardware_config()), ...
                'lw:stage:PulseWidthBelowMinimum');
        end

        function offGridWritingPlanDwellIsRejected(testCase)
            path = writePlan(testCase, 150e-6, 0, "point");
            trajectory = lw_import_writing_plan_table(path);

            testCase.verifyError(@() lw_prepare_point_run_trajectory( ...
                trajectory, 100e-6, 0, lw_hardware_config()), ...
                'lw:stage:PulseWidthResolution');
        end

        function scanOnlyPlanDoesNotClaimPointMode(testCase)
            path = writePlan(testCase, NaN, 0.1, "scan");
            trajectory = lw_import_writing_plan_table(path);

            testCase.verifyEqual(string(trajectory.modeSupport), "stream");
            testCase.verifyFalse(supportsMode(trajectory, "point"));
        end

        function executorUsesPerPointDwellAndSettlesBeforeExposure(testCase)
            trajectory = lw_make_trajectory([1; 2], [3; 4], [5; 6], [7; 8], ...
                "test", "point", struct('powerSource', "file"));
            trajectory.dwellSeconds = [100e-6; 200e-6];
            trajectory.preWritePauseSeconds = [0.001; 0];
            trajectory.meta.pointTimingSource = "trajectory";

            events = ValueBox(strings(0, 1));
            exposureValues = ValueBox(zeros(0, 2));
            options = struct( ...
                'moveFcn', @(state, target, motion, moveOptions) ...
                    fakeMove(events, state, target, motion, moveOptions), ...
                'exposureFcn', @(state, config, power, dwell, laserStateFcn, shouldStopFcn, yieldFcn) ...
                    fakeExposure(events, exposureValues, state, config, power, dwell, ...
                    laserStateFcn, shouldStopFcn, yieldFcn), ...
                'progressFcn', @(index, total, target, phase) ...
                    recordProgress(events, index, total, target, phase), ...
                'yieldFcn', @() [], ...
                'shouldStopFcn', @() false, ...
                'pauseRequestedFcn', @() false);
            state = struct('currentPosition', struct('x', 0, 'y', 0, 'z', 0));

            [state, result] = lw_run_point_mode( ...
                state, lw_hardware_config(), trajectory, options);

            testCase.verifyEqual(result.status, "finished");
            testCase.verifyEqual(state.currentPosition, struct('x', 2, 'y', 4, 'z', 6));
            testCase.verifyEqual(exposureValues.Value, [7, 100e-6; 8, 200e-6], 'AbsTol', 1e-12);
            firstSettle = find(events.Value == "1:Settling", 1, 'first');
            firstExpose = find(events.Value == "1:Exposing", 1, 'first');
            firstFire = find(events.Value == "1:Fire", 1, 'first');
            testCase.verifyLessThan(firstSettle, firstExpose);
            testCase.verifyLessThan(firstExpose, firstFire);
            testCase.verifyFalse(any(events.Value == "2:Settling"));
        end

        function hardwareExposureUsesFirmwareSchedule(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            textValue = fileread(fullfile(projectRoot, 'src', 'hardware', 'lw_manual_exposure.m'));

            testCase.verifyNotEmpty(strfind(textValue, 'lw_schedule_stage_pulse_trigger'));
            testCase.verifyEmpty(strfind(textValue, 'lw_set_stage_pulse_trigger(state, true'));
        end

        function configuredPolarityMapsActiveAndSafeStates(testCase)
            lw_ensure_zaber_motion_library();
            config = lw_hardware_config();

            activeAction = lw_stage_pulse_trigger_action(true, config);
            safeAction = lw_stage_pulse_trigger_action(false, config);
            testCase.verifyEqual(string(activeAction.toString()), "ON");
            testCase.verifyEqual(string(safeAction.toString()), "OFF");

            config.stage.pulseTriggerActiveHigh = false;
            activeAction = lw_stage_pulse_trigger_action(true, config);
            safeAction = lw_stage_pulse_trigger_action(false, config);
            testCase.verifyEqual(string(activeAction.toString()), "OFF");
            testCase.verifyEqual(string(safeAction.toString()), "ON");
        end
    end
end

function path = writePlan(testCase, dwellSeconds, pauseSeconds, modes)
dwellSeconds = dwellSeconds(:);
pauseSeconds = pauseSeconds(:);
modes = string(modes(:));
rowCount = max([numel(dwellSeconds), numel(pauseSeconds), numel(modes)]);
dwellSeconds = repmat(dwellSeconds, rowCount / numel(dwellSeconds), 1);
pauseSeconds = repmat(pauseSeconds, rowCount / numel(pauseSeconds), 1);
modes = repmat(modes, rowCount / numel(modes), 1);

x = (0:rowCount - 1).';
y = zeros(rowCount, 1);
z = zeros(rowCount, 1);
x2 = x + 1;
y2 = y;
z2 = z;
power = repmat(10, rowCount, 1);
scanSpeed = ones(rowCount, 1);
pointMask = modes == "point";
x2(pointMask) = NaN;
y2(pointMask) = NaN;
z2(pointMask) = NaN;
scanSpeed(pointMask) = NaN;

plan = table(modes, x, y, z, x2, y2, z2, power, dwellSeconds, scanSpeed, pauseSeconds, ...
    'VariableNames', {'mode', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'power', 'dwell_s', 'scan_speed_mm_s', 'pause_s'});
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
path = fullfile(folder, 'writing_plan.csv');
writetable(plan, path);
end

function [state, wasStopped] = fakeMove(events, state, target, ~, ~)
events.Value(end + 1) = sprintf('%g:Move', target.x);
state.currentPosition = target;
wasStopped = false;
end

function wasStopped = fakeExposure(events, exposureValues, ~, ~, power, dwell, ~, ~, ~)
pointIndex = size(exposureValues.Value, 1) + 1;
events.Value(end + 1) = sprintf('%d:Fire', pointIndex);
exposureValues.Value(end + 1, :) = [power, dwell];
wasStopped = false;
end

function recordProgress(events, index, ~, ~, phase)
events.Value(end + 1) = sprintf('%d:%s', index, char(phase));
end
