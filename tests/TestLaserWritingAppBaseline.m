classdef TestLaserWritingAppBaseline < matlab.unittest.TestCase
    properties (Constant, Access = private)
        ExpectedComponentCount = 645
        ExpectedSignatureHash = "4a979327e08f68f4361ba188c9a61ac819c513d10f5eae4242ed2f39e903ffb7"
    end

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
        function refactoredStartupStructureMatchesBaseline(testCase)
            fig = laser_writing_app_refactored();
            cleanup = onCleanup(@() closeIfValid(fig));
            drawnow;

            testCase.verifyUiBaseline(fig);
        end

        function refactoredCloseDoesNotLeakTimers(testCase)
            timersBefore = timerfindall();
            fig = laser_writing_app_refactored();
            drawnow;
            close(fig);
            drawnow;
            timersAfter = timerfindall();
            testCase.verifyEqual(numel(timersAfter), numel(timersBefore));
        end
    end

    methods (Access = private)
        function verifyUiBaseline(testCase, fig)
            testCase.verifyClass(fig, 'matlab.ui.Figure');
            testCase.verifyEqual(fig.Name, '3D Laser Writing Control App');
            testCase.verifyEqual(fig.Position, [80, 60, 1440, 900]);
            testCase.verifyEqual(numel(findall(fig)), testCase.ExpectedComponentCount);

            [~, hash] = lw_test_ui_signature(fig);
            testCase.verifyEqual(hash, testCase.ExpectedSignatureHash);
        end
    end
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
