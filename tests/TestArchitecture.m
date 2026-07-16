classdef TestArchitecture < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(~)
            [projectRoot, ~] = roots();
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function standaloneRuntimeDependenciesAreBundled(testCase)
            [projectRoot, refactorRoot] = roots();
            testCase.verifyEqual(projectRoot, refactorRoot);
            requiredFiles = [ ...
                "app/mako_camera_control_app.m", ...
                "config/lw_hardware_config.m", ...
                "scripts/lw_setup_project.m", ...
                "src/hardware/lw_move_absolute.m", ...
                "src/ui/lw_build_control_tab.m", ...
                "slm_control/lw_slm_control_app.m"];
            for relativePath = requiredFiles
                testCase.verifyTrue(isfile(fullfile(refactorRoot, relativePath)), ...
                    sprintf('Standalone runtime dependency is missing: %s', relativePath));
            end
            testCase.verifyFalse(isfile(fullfile(refactorRoot, 'laser_writing_app.m')), ...
                'The original application entry point must not be bundled into the standalone folder.');
        end

        function launcherDoesNotResolveTheParentProject(testCase)
            [~, refactorRoot] = roots();
            text = normalizedFileText(fullfile(refactorRoot, 'laser_writing_app_refactored.m'));
            testCase.verifyNotEmpty(regexp(text, 'projectRoot\s*=\s*refactorRoot', 'once'));
            testCase.verifyEmpty(regexp(text, 'projectRoot\s*=\s*fileparts\(refactorRoot\)', 'once'));
        end

        function refactoredEntryIsThinAndHasNoNestedFunctions(testCase)
            [~, refactorRoot] = roots();
            text = normalizedFileText(fullfile(refactorRoot, 'laser_writing_app_refactored.m'));
            testCase.verifyLessThanOrEqual(numel(splitlines(string(text))), 80);
            testCase.verifyEqual(numel(regexp(text, '(?m)^function\s+', 'match')), 1);
        end

        function appControllerUsesClassMethodsNotNestedClosure(testCase)
            [~, refactorRoot] = roots();
            path = fullfile(refactorRoot, 'src', '+lw', '+app', 'AppController.m');
            text = normalizedFileText(path);
            testCase.verifyEmpty(regexp(text, '(?m)^    function\s+', 'once'));
            testCase.verifyNotEmpty(regexp(text, '(?m)^        function\s+', 'once'));
        end

        function methodHandlesDoNotUseChainedObjectExpressions(testCase)
            [~, refactorRoot] = roots();
            files = dir(fullfile(refactorRoot, 'src', '**', '*.m'));
            pattern = '@[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*){2,}';
            for fileIndex = 1:numel(files)
                path = fullfile(files(fileIndex).folder, files(fileIndex).name);
                matches = regexp(normalizedFileText(path), pattern, 'match');
                testCase.verifyEmpty(matches, sprintf( ...
                    'Chained method handle in %s must bind through a local object alias.', path));
            end
        end

        function requiredControllersExist(testCase)
            classNames = [ ...
                "lw.app.AppController", "lw.app.Model", "lw.app.StageLaserController", ...
                "lw.app.CarbideController", "lw.app.FlirController", ...
                "lw.app.TrajectoryController", "lw.app.RunController", ...
                "lw.app.ImagingController", "lw.app.UiPolicyController", ...
                "lw.app.SafetyCoordinator"];
            for className = classNames
                testCase.verifyEqual(exist(className, 'class'), 8, ...
                    sprintf('Missing architecture class %s.', className));
            end
        end
    end
end

function [projectRoot, refactorRoot] = roots()
refactorRoot = fileparts(fileparts(mfilename('fullpath')));
projectRoot = refactorRoot;
end

function text = normalizedFileText(path)
text = fileread(path);
text = regexprep(text, '\r\n?', '\n');
end
