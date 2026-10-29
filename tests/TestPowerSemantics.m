classdef TestPowerSemantics < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(~)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(refactorRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function generatedPlansStoreTheirExecutionPower(testCase)
            frame = lw_generate_frame_trajectory(3, 2, 0.01, 0.02, 7.5);
            mark = lw_generate_mark_trajectory("A", 0.01, 12);

            testCase.verifyEqual(frame.power, repmat(7.5, size(frame.x)));
            testCase.verifyEqual(mark.power, repmat(12, size(mark.x)));
            testCase.verifyEqual(string(frame.meta.powerSource), "plan");
            testCase.verifyEqual(string(mark.meta.powerSource), "plan");
        end

        function missingFilePowerRequiresEnabledOverride(testCase)
            path = testCase.writeNumericFile([0 0 0; 1 2 3]);
            testCase.verifyError(@() lw_import_points_table(path, false, 8), ...
                'lw:MissingInputPower');

            trajectory = lw_import_points_table(path, true, 8);

            testCase.verifyEqual(trajectory.power, [8; 8]);
            testCase.verifyEqual(string(trajectory.meta.powerSource), "fixed_override");
        end

        function xyzpImportUsesFilePowerWhenOverrideIsOff(testCase)
            path = testCase.writeNumericFile([0 0 0 4; 1 2 3 9]);
            trajectory = lw_import_points_table(path, false, 77);

            testCase.verifyEqual(trajectory.power, [4; 9]);
            testCase.verifyEqual(string(trajectory.meta.powerSource), "file");
        end

        function xyzpImportUsesFixedPowerWhenOverrideIsOn(testCase)
            path = testCase.writeNumericFile([0 0 0 4; 1 2 3 9]);
            trajectory = lw_import_points_table(path, true, 77);

            testCase.verifyEqual(trajectory.power, [77; 77]);
            testCase.verifyEqual(string(trajectory.meta.powerSource), "fixed_override");
            testCase.verifyTrue(trajectory.meta.fixedPowerOverride);
            testCase.verifyEqual(trajectory.meta.fixedPowerPercent, 77);
        end

        function writingPlanOverrideUpdatesCanonicalPower(testCase)
            path = testCase.writeWritingPlan([4; 9]);
            trajectory = lw_import_points_table(path, true, 12.5);

            testCase.verifyEqual(trajectory.power, [12.5; 12.5]);
            testCase.verifyEqual(trajectory.writingPlan.power, [12.5; 12.5]);
            testCase.verifyEqual(string(trajectory.meta.powerSource), "fixed_override");
        end

        function powerValidationRejectsOutOfRangeValues(testCase)
            testCase.verifyEqual(validatePowerPercent(0, 'Power'), 0);
            testCase.verifyEqual(validatePowerPercent(100, 'Power'), 100);
            testCase.verifyError(@() validatePowerPercent(-0.1, 'Power'), 'lw:InvalidPowerPercent');
            testCase.verifyError(@() validatePowerPercent(100.1, 'Power'), 'lw:InvalidPowerPercent');
        end
    end

    methods (Access = private)
        function path = writeNumericFile(testCase, values)
            folder = tempname;
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            path = fullfile(folder, 'points.csv');
            writematrix(values, path);
        end

        function path = writeWritingPlan(testCase, power)
            folder = tempname;
            mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            path = fullfile(folder, 'writing_plan.csv');
            mode = ["point"; "point"];
            x_mm = [0; 1];
            y_mm = [0; 2];
            z_mm = [0; 3];
            x2_mm = [nan; nan];
            y2_mm = [nan; nan];
            z2_mm = [nan; nan];
            dwell_s = [0.001; 0.002];
            scan_speed_mm_s = [nan; nan];
            pause_s = [0; 0];
            plan = table(mode, x_mm, y_mm, z_mm, x2_mm, y2_mm, z2_mm, ...
                power, dwell_s, scan_speed_mm_s, pause_s);
            writetable(plan, path);
        end
    end
end
