classdef TestAutoExposureSettings < matlab.unittest.TestCase
    %TESTAUTOEXPOSURESETTINGS Safety factor validation, preflight text, and the >1 warning.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(refactorRoot, 'scripts'));
            lw_setup_project();
            helperPath = fullfile(refactorRoot, 'tests', 'helpers');
            addpath(helperPath);
            testCase.addTeardown(@() rmpath(helperPath));
        end
    end

    methods (Test)
        function safetyFactorAcceptsOneAndAbove(testCase)
            testCase.verifyEqual(lw_validate_auto_exposure_safety_factor(0.8, "3D imaging"), 0.8);
            testCase.verifyEqual(lw_validate_auto_exposure_safety_factor(1, "3D imaging"), 1);
            testCase.verifyEqual(lw_validate_auto_exposure_safety_factor(1.5, "3D imaging"), 1.5);
        end

        function safetyFactorRejectsNonPositiveValues(testCase)
            for badValue = {0, -0.5, NaN, Inf, [0.5, 0.8]}
                testCase.verifyError(@() lw_validate_auto_exposure_safety_factor(badValue{1}, "3D imaging"), ...
                    ?MException);
            end
        end

        function summaryFlagsSaturationOnlyAboveOne(testCase)
            testCase.verifyEqual(lw_format_auto_exposure_summary(struct('enabled', false)), "Off");
            testCase.verifyEqual(lw_format_auto_exposure_summary(scoutOptions(1)), ...
                "On (10 Z samples, 100% no-clip target)");
            testCase.verifyEqual(lw_format_auto_exposure_summary(scoutOptions(1.2)), ...
                "On (10 Z samples, 120% no-clip target; above 100% the brightest pixels will saturate)");
        end

        function singleStackPreflightShowsSaturationWarning(testCase)
            preflight = struct( ...
                'zPositions', 24.555:0.01:26.255, 'x', 25.013, 'displayY', 14.569, ...
                'zStart', 24.555, 'zEnd', 26.255, 'zStep', 0.01, 'settlingTime', 0.1, ...
                'exposureUs', 96, 'gain', 0, 'captureTimeoutMs', 1500, ...
                'runFolder', 'C:\out\run', 'stackFile', 'C:\out\run\stack.tif', ...
                'slmSnapshot', [], 'slmFilenameToken', "", ...
                'autoExposure', scoutOptions(1.5), 'flirRoiText', "500 x 500 @ (1980, 700)");
            summaryText = lw_build_3d_imaging_preflight_summary_text(preflight, true, true);
            testCase.verifyTrue(contains(summaryText, "150% no-clip target; above 100%"));
            testCase.verifyTrue(contains(summaryText, "FLIR ROI: 500 x 500 @ (1980, 700)"));
        end

        function warningPopsUpOnlyAboveOne(testCase)
            alerts = ValueBox(strings(1, 0));
            services = lw.app.defaultServices(struct('dialog', struct( ...
                'alert', @(~, message, varargin) appendText(alerts, message))));
            model = lw.app.Model(lw_hardware_config(), lw_default_state(), services);
            imaging = lw.app.ImagingController(model, unusedImagingPorts());

            imaging.onAutoExposureSafetyFactorChanged(struct('Value', 1), []);
            imaging.onAutoExposureSafetyFactorChanged(struct('Value', 0.8), []);
            testCase.verifyEmpty(alerts.Value);

            imaging.onAutoExposureSafetyFactorChanged(struct('Value', 1.25), []);
            testCase.verifyNumElements(alerts.Value, 1);
            testCase.verifyTrue(contains(alerts.Value(1), "125%"));
        end
    end
end

function options = scoutOptions(safetyFactor)
options = struct('enabled', true, 'sampleCount', 10, 'safetyFactor', safetyFactor, 'maxRetries', 8);
end

function appendText(box, text)
box.Value(end + 1) = string(text);
end

function ports = unusedImagingPorts()
% The safety-factor warning only uses the dialog service, so every port is a stub.
names = ["carbide", "displayYToStage", "flir", "logMessage", "runUiAction", ...
    "stageLaser", "stageYToDisplay", "syncAll", "syncPositionFields", ...
    "trajectory", "validateTargetForUi"];
ports = struct();
for name = names
    ports.(name) = @(varargin) [];
end
end
