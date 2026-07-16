classdef TestDependencyContracts < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(~)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            projectRoot = refactorRoot;
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function productionServicesSatisfyContract(testCase)
            services = lw.app.defaultServices();
            testCase.verifyEqual(lw.app.validateServices(services), services);
        end

        function missingControllerPortFailsFast(testCase)
            testCase.verifyError( ...
                @() lw.app.validatePorts("ExampleController", struct(), "logMessage"), ...
                'lw:app:MissingDependency');
        end

        function invalidServiceOverrideFailsFast(testCase)
            services = lw.app.defaultServices(struct( ...
                'stage', struct('connect', [])));
            testCase.verifyError(@() lw.app.validateServices(services), ...
                'lw:app:MissingDependency');
        end
    end
end
