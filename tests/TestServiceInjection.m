classdef TestServiceInjection < matlab.unittest.TestCase
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
        function partialOverridesKeepProductionDefaults(testCase)
            fakeConnect = @(state, ~) state;
            services = lw.app.defaultServices(struct( ...
                'stage', struct('connect', fakeConnect)));

            testCase.verifyEqual(services.stage.connect, fakeConnect);
            testCase.verifyTrue(isa(services.stage.home, 'function_handle'));
            testCase.verifyTrue(isa(services.flir.capture, 'function_handle'));
            testCase.verifyTrue(isa(services.dialog.confirm, 'function_handle'));
        end

        function closeUsesInjectedServices(testCase)
            calls = ValueBox(strings(1, 0));
            overrides = struct( ...
                'slm', struct('batchAction', @(~, ~, ~, ~) recordCall(calls, "slm")), ...
                'stage', struct('disconnectAll', @(state, ~) recordState(calls, "stage", state)));

            fig = laser_writing_app_refactored(overrides);
            cleanup = onCleanup(@() deleteIfValid(fig));
            drawnow;
            close(fig);
            drawnow;

            testCase.verifyEqual(calls.Value, ["slm", "stage"]);
        end
    end
end

function recordCall(calls, name)
calls.Value(end + 1) = name;
end

function state = recordState(calls, name, state)
calls.Value(end + 1) = name;
end

function deleteIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    delete(fig);
end
end
