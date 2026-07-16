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

        function xyzOnlyImportUsesPlanPower(testCase)
            path = testCase.writeNumericFile([0 0 0; 1 2 3]);
            trajectory = lw_import_points_table(path, 8);

            testCase.verifyEqual(trajectory.power, [8; 8]);
            testCase.verifyEqual(string(trajectory.meta.powerSource), "plan");
        end

        function xyzpImportAlwaysUsesFilePower(testCase)
            path = testCase.writeNumericFile([0 0 0 4; 1 2 3 9]);
            trajectory = lw_import_points_table(path, 77);

            testCase.verifyEqual(trajectory.power, [4; 9]);
            testCase.verifyEqual(string(trajectory.meta.powerSource), "file");
        end

        function streamAcceptsAnyConstantPlanPower(testCase)
            trajectory = lw_make_trajectory([0; 1], [0; 0], [0; 0], [6; 6], ...
                "imported_points", "point+stream", struct('powerSource', "file"));

            testCase.verifyEqual(trajectoryConstantPower(trajectory), 6);
        end

        function streamRejectsVariablePlanPower(testCase)
            trajectory = lw_make_trajectory([0; 1], [0; 0], [0; 0], [6; 7], ...
                "imported_points", "point+stream", struct('powerSource', "file"));

            testCase.verifyError(@() trajectoryConstantPower(trajectory), 'lw:VariableStreamPower');
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
    end
end
