classdef TestSlmInitialization < matlab.unittest.TestCase
    properties
        Config
        Sdk
        Context
    end

    properties (TestParameter)
        coreFailure = { ...
            struct('operation', 'heds_slmwindow_slmsetup_add_screen', ...
                'stage', 'configuring the SLM screen'), ...
            struct('operation', 'heds_slmwindow_slmsetup_apply', ...
                'stage', 'configuring the SLM screen'), ...
            struct('operation', 'heds_slm_set_wavelength', ...
                'stage', 'setting the SLM wavelength'), ...
            struct('operation', 'heds_slm_width_px', ...
                'stage', 'reading the SLM resolution'), ...
            struct('operation', 'heds_slm_height_px', ...
                'stage', 'reading the SLM resolution')}
        previewFailure = {'heds_slmpreview_open', 'heds_slmpreview_set_settings'}
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            folders = {fullfile(projectRoot, 'slm_control', 'src'), ...
                fullfile(projectRoot, 'slm_control', 'config'), ...
                fullfile(projectRoot, 'tests', 'helpers')};
            for index = 1:numel(folders)
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folders{index}));
            end
        end
    end

    methods (TestMethodSetup)
        function installHardwareFreeSdk(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            apiPath = fullfile(folder.Folder, 'api', 'matlab');
            mkdir(apiPath);
            writeSdkStubs(apiPath);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(apiPath));

            global slmInitializationTestSdk heds_types %#ok<GVMIS>
            previousSdk = slmInitializationTestSdk;
            previousTypes = heds_types;
            testCase.addTeardown(@() restoreGlobals(previousSdk, previousTypes));
            testCase.Sdk = FakeSlmInitializationSdk();
            slmInitializationTestSdk = testCase.Sdk;

            testCase.Config = slm_config();
            testCase.Config.sdkPath = folder.Folder;
            testCase.Config.closeExistingWindowsOnInit = false;
            testCase.Config.printSdkVersion = false;
            testCase.Config.openPreview = false;
            testCase.Context = [];
        end
    end

    methods (Test)
        function connectionUsesConfiguredDeviceAndFirstSlm(testCase)
            testCase.Config.preselect = 'name:test-pluto';
            testCase.Config.wavelengthNm = 920.25;
            testCase.Config.sdkVersionMinor = 7;
            testCase.Config.printSdkVersion = true;
            testCase.Config.closeExistingWindowsOnInit = true;
            testCase.Config.openPreview = true;
            testCase.Config.previewScale = 0.375;

            ctx = slm_init(testCase.Config);

            testCase.verifyTrue(ctx.initialized);
            testCase.verifyEqual(ctx.config, testCase.Config);
            testCase.verifyEqual(ctx.slm, struct('slmwindow_id', 101, 'slm_id', 1));
            testCase.verifyEqual([ctx.widthPx, ctx.heightPx], [1920, 1080]);
            testCase.verifyClass(ctx.widthPx, 'double');
            testCase.verifyClass(ctx.heightPx, 'double');
            testCase.verifyEqual(ctx.sdkTypes.HEDSSLMPF_None, int32(0));
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_sdk_init'), {{4, 7}});
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_sdk_print_version'), {{}});
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_sdk_close_all'), {{}});
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_slmwindow_open'), ...
                {{'name:test-pluto'}});
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_slm_set_wavelength'), ...
                {{ctx.slm, single(920.25), true}});
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_slmpreview_set_settings'), ...
                {{101, int32(0), 0.375}});
            testCase.verifyEqual(testCase.Sdk.ActiveWindows, 101);
            testCase.verifyEqual(testCase.Sdk.ActivePreviews, 101);
            testCase.verifyEmpty(ctx.previewWarning);
            names = {testCase.Sdk.Calls.name};
            testCase.verifyLessThan(find(strcmp(names, 'heds_slm_height_px'), 1), ...
                find(strcmp(names, 'heds_slmpreview_open'), 1));
        end

        function failedCoreSetupCleansItsWindowAndAllowsRetry(testCase, coreFailure)
            testCase.Sdk.FailOnce = coreFailure.operation;
            err = captureFailure(@() slm_init(testCase.Config));

            testCase.assertClass(err, 'MException');
            testCase.verifyEqual(err.identifier, 'SLM:ConnectionFailed');
            testCase.verifySubstring(err.message, coreFailure.stage);
            testCase.verifySubstring(err.message, testCase.Config.sdkPath);
            testCase.verifySubstring(err.message, testCase.Config.preselect);
            testCase.assertNumElements(err.cause, 1);
            testCase.verifyEqual(err.cause{1}.identifier, 'test:SlmSdkFailure');
            testCase.verifySubstring(err.cause{1}.message, coreFailure.operation);
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_slmwindow_close'), {{101}});
            testCase.verifyEqual(testCase.Sdk.ActiveWindows, 900);
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_sdk_close_all'));
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmpreview_open'));

            ctx = slm_init(testCase.Config);

            testCase.verifyTrue(ctx.initialized);
            testCase.verifyEqual(ctx.slm.slmwindow_id, 102);
            testCase.verifyEqual(testCase.Sdk.ActiveWindows, [900, 102]);
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_slmwindow_close'), {{101}});
        end

        function failedOpenDoesNotCloseAnUnrelatedWindow(testCase)
            testCase.Sdk.FailOnce = 'heds_slmwindow_open';

            err = captureFailure(@() slm_init(testCase.Config));

            testCase.assertClass(err, 'MException');
            testCase.verifyEqual(err.identifier, 'SLM:ConnectionFailed');
            testCase.verifySubstring(err.message, 'opening the SLM window');
            testCase.verifyEqual(testCase.Sdk.ActiveWindows, 900);
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmwindow_close'));
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_sdk_close_all'));
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmwindow_slmsetup_apply'));
        end

        function previewFailureKeepsConnectionAndReleasesPartialPreview(testCase, previewFailure)
            testCase.Config.openPreview = true;
            testCase.Sdk.FailOnce = previewFailure;

            testCase.verifyWarning(@() testCase.captureConnection(), 'SLM:PreviewUnavailable');

            ctx = testCase.Context;
            testCase.verifyTrue(ctx.initialized);
            testCase.verifyEqual([ctx.widthPx, ctx.heightPx], [1920, 1080]);
            testCase.verifySubstring(ctx.previewWarning, previewFailure);
            testCase.verifyEqual(testCase.Sdk.ActiveWindows, [900, 101]);
            testCase.verifyEmpty(testCase.Sdk.ActivePreviews);
            testCase.verifyEqual(testCase.Sdk.argumentsFor('heds_slmpreview_close'), {{101}});
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmwindow_close'));
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_sdk_close_all'));

            % The retained context remains usable, including a later preview retry.
            slm_open_sdk_preview(ctx, 0.5);
            testCase.verifyEqual(testCase.Sdk.ActivePreviews, 101);
        end

        function disabledPreviewDoesNotOpenOrClosePreview(testCase)
            ctx = slm_init(testCase.Config);

            testCase.verifyTrue(ctx.initialized);
            testCase.verifyEmpty(ctx.previewWarning);
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmpreview_open'));
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmpreview_close'));
        end

        function unexpectedResolutionStillReturnsUsableConnection(testCase)
            testCase.Sdk.WidthPx = uint32(1280);
            testCase.Sdk.HeightPx = uint32(720);

            testCase.verifyWarning(@() testCase.captureConnection(), 'SLM:UnexpectedResolution');

            testCase.verifyTrue(testCase.Context.initialized);
            testCase.verifyEqual([testCase.Context.widthPx, testCase.Context.heightPx], [1280, 720]);
            testCase.verifyEqual(testCase.Sdk.ActiveWindows, [900, 101]);
            testCase.verifyEmpty(testCase.Sdk.argumentsFor('heds_slmwindow_close'));
        end
    end

    methods (Access = private)
        function captureConnection(testCase)
            testCase.Context = slm_init(testCase.Config);
        end
    end
end

function writeSdkStubs(apiPath)
names = {'load_heds_types', 'heds_sdk_print_version', 'heds_sdk_init', ...
    'heds_sdk_close_all', 'heds_slm_init', 'heds_slmwindow_open', ...
    'heds_slmwindow_slmsetup_add_screen', 'heds_slmwindow_slmsetup_apply', ...
    'heds_slmwindow_close', 'heds_slm_set_wavelength', 'heds_slm_width_px', ...
    'heds_slm_height_px', 'heds_slmpreview_open', ...
    'heds_slmpreview_set_settings', 'heds_slmpreview_close'};
for index = 1:numel(names)
    name = names{index};
    fileId = fopen(fullfile(apiPath, [name, '.m']), 'w');
    assert(fileId ~= -1, 'test:StubCreationFailed', 'Could not create SDK stub.');
    cleanup = onCleanup(@() fclose(fileId));
    fprintf(fileId, ['function varargout = %s(varargin)\n', ...
        'global slmInitializationTestSdk\n', ...
        '[varargout{1:nargout}] = slmInitializationTestSdk.invoke(''%s'', varargin{:});\n', ...
        'end\n'], name, name);
    clear cleanup
end
end

function err = captureFailure(action)
err = [];
try
    action();
catch caught
    err = caught;
end
end

function restoreGlobals(previousSdk, previousTypes)
global slmInitializationTestSdk heds_types %#ok<GVMIS>
slmInitializationTestSdk = previousSdk;
heds_types = previousTypes;
end
