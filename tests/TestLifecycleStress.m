classdef TestLifecycleStress < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(~)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            projectRoot = refactorRoot;
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function tenStartupCloseCyclesLeaveNoUiOrTimerHandles(testCase)
            figuresBefore = findall(groot, 'Type', 'figure');
            timersBefore = timerfindall();

            for cycle = 1:10
                fig = laser_writing_app_refactored();
                drawnow;
                testCase.verifyTrue(isvalid(fig), ...
                    sprintf('Figure was invalid during cycle %d.', cycle));
                close(fig);
                drawnow;
                testCase.verifyFalse(isvalid(fig), ...
                    sprintf('Figure survived close during cycle %d.', cycle));
            end

            figuresAfter = findall(groot, 'Type', 'figure');
            timersAfter = timerfindall();
            testCase.verifyEqual(numel(figuresAfter), numel(figuresBefore));
            testCase.verifyEqual(numel(timersAfter), numel(timersBefore));
        end
    end
end
