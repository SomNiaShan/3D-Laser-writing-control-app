classdef TestFlirRoiController < matlab.unittest.TestCase
    %TESTFLIRROICONTROLLER FLIR ROI panel, persistence, and live-rectangle mapping without hardware.

    properties
        Folder
        Figure
    end

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

    methods (TestMethodSetup)
        function createWorkspace(testCase)
            testCase.Folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.Figure = uifigure('Visible', 'off');
            testCase.addTeardown(@() deleteIfValid(testCase.Figure));
        end
    end

    methods (Test)
        function applyCustomRoiWritesCameraAndPersists(testCase)
            [flir, model, nodes] = testCase.createController();
            setRoiUi(model, 'Custom', [3497, 2495, 501, 499]);

            flir.applyFlirRoiImpl();

            testCase.verifyEqual(roiUiValues(model), [3496, 2496, 500, 500]);
            testCase.verifyEqual([nodes.OffsetX.Value, nodes.OffsetY.Value, nodes.Width.Value, nodes.Height.Value], ...
                [3496, 2496, 500, 500]);
            testCase.verifyEqual(flir.flirCaptureRegion(), ...
                struct('OffsetX', 3496, 'OffsetY', 2496, 'Width', 500, 'Height', 500));
            testCase.verifyTrue(contains(string(model.Ui.FlirRoiInfoLabel.Text), "Sensor 4000 x 3000"));
            saved = jsondecode(fileread(testCase.settingsFile()));
            testCase.verifyEqual(string(saved.Mode), "custom");
            testCase.verifyEqual([saved.OffsetX, saved.OffsetY, saved.Width, saved.Height], [3496, 2496, 500, 500]);
        end

        function savedRoiIsRestoredAtStartup(testCase)
            lw_flir_roi_selection_save(testCase.settingsFile(), ...
                lw_flir_roi_selection("custom", struct('OffsetX', 1996, 'OffsetY', 686, 'Width', 500, 'Height', 500)));
            [flir, model, ~, logs] = testCase.createController();

            testCase.verifyEqual(model.Ui.FlirRoiModeDropDown.Value, 'Custom');
            testCase.verifyEqual(roiUiValues(model), [1996, 686, 500, 500]);
            testCase.verifyEqual(flir.flirRoiSelectionText(), "500 x 500 @ (1996, 686)");
            testCase.verifyTrue(any(contains(logs.Value, "Loaded saved FLIR ROI")));
        end

        function presetKeepsCustomFieldValues(testCase)
            [flir, model, nodes] = testCase.createController();
            setRoiUi(model, 'Full sensor', [1996, 686, 500, 500]);

            flir.applyFlirRoiImpl();

            testCase.verifyEqual(flir.flirCaptureRegion(), "full");
            testCase.verifyEqual([nodes.Width.Value, nodes.Height.Value], [4000, 3000]);
            testCase.verifyEqual(roiUiValues(model), [1996, 686, 500, 500]);
            testCase.verifyFalse(flir.isFlirRoiCustomModeSelected());
        end

        function unappliedEditsAreFlaggedForPreflight(testCase)
            [flir, model] = testCase.createController();
            setRoiUi(model, 'Custom', [1996, 686, 500, 500]);
            flir.applyFlirRoiImpl();
            testCase.verifyFalse(flir.hasUnappliedFlirRoiEdits());

            model.Ui.FlirRoiWidthField.Value = 640;
            testCase.verifyTrue(flir.hasUnappliedFlirRoiEdits());
            testCase.verifyTrue(contains(flir.flirRoiPreflightText(), "unapplied"));
            testCase.verifyEqual(flir.flirCaptureRegion().Width, 500);
        end

        function centerKeepsSizeAndCentersOnSensor(testCase)
            [flir, model] = testCase.createController();
            setRoiUi(model, 'Custom', [0, 0, 500, 500]);

            flir.centerFlirRoiImpl();

            % (4000 - 500) / 2 = 1750 is off the 4 px OffsetX step and rounds to 1752.
            testCase.verifyEqual(roiUiValues(model), [1752, 1250, 500, 500]);
        end

        function liveRectangleMapsToSensorPixels(testCase)
            testCase.assumeEqual(exist('images.roi.Rectangle', 'class'), 8, ...
                'Image Processing Toolbox is required for Draw ROI.');
            [flir, model] = testCase.createController();
            flir.buildFlirLiveWindow();
            testCase.addTeardown(@() flir.flirLive('delete'));
            flir.showFlirLiveFrame(zeros(300, 400, 'uint8'), ...
                struct('Width', 400, 'Height', 300, 'PixelFormat', 'Mono8', 'OffsetX', 1000, 'OffsetY', 500));
            model.Ui.FlirRoiEditBase = struct('OffsetX', 1000, 'OffsetY', 500);
            model.Ui.FlirRoiEditActive = true;
            rect = images.roi.Rectangle(model.Ui.FlirLiveAxes, 'Position', [12.5, 20.5, 101, 49]);
            model.Ui.FlirRoiDrawRect = rect;

            flir.updateFlirRoiFieldsFromLiveRect(rect, flir.requireFlirRoiLimits());

            testCase.verifyEqual(model.Ui.FlirRoiModeDropDown.Value, 'Custom');
            testCase.verifyEqual(roiUiValues(model), [1012, 520, 100, 50]);
            testCase.verifyEqual(rect.Position, [12.5, 20.5, 100, 50]);
            testCase.verifyTrue(flir.isFlirLiveRoiDrawn());

            flir.cancelFlirLiveRoiEditImpl();
            testCase.verifyFalse(model.Ui.FlirRoiEditActive);
            testCase.verifyFalse(isvalid(rect));
            testCase.verifyEqual(model.Ui.FlirRoiModeDropDown.Value, 'Top-left quarter');
        end
    end

    methods (Access = private)
        function path = settingsFile(testCase)
            path = fullfile(testCase.Folder, 'settings', 'flir_roi.json');
        end

        function [flir, model, nodes, logs] = createController(testCase)
            config = lw_hardware_config();
            config.imaging.roiSettingsFile = testCase.settingsFile();
            model = lw.app.Model(config, lw_default_state(), lw.app.defaultServices());
            model.Figure = testCase.Figure;
            [model.State.flir, nodes] = fakeConnectedFlir();

            logs = ValueBox(strings(1, 0));
            ports = struct( ...
                'logMessage', @(message) appendLog(logs, message), ...
                'mergeUi', @(newUi) model.mergeUi(newUi), ...
                'runUiAction', @(actionFcn, ~) actionFcn(), ...
                'showImagingFrame', @(varargin) [], ...
                'uiBuildHelpers', @uiHelpers);
            flir = lw.app.FlirController(model, ports);

            tab = uitab(uitabgroup(testCase.Figure));
            model.mergeUi(lw_build_imaging_tab(tab, imagingCallbacks(), uiHelpers()));
            flir.loadSavedFlirRoiSelection();
            flir.refreshFlirRoiLimits(false);
        end
    end
end

function setRoiUi(model, modeLabel, values)
model.Ui.FlirRoiModeDropDown.Value = modeLabel;
model.Ui.FlirRoiOffsetXField.Value = values(1);
model.Ui.FlirRoiOffsetYField.Value = values(2);
model.Ui.FlirRoiWidthField.Value = values(3);
model.Ui.FlirRoiHeightField.Value = values(4);
end

function values = roiUiValues(model)
values = [model.Ui.FlirRoiOffsetXField.Value, model.Ui.FlirRoiOffsetYField.Value, ...
    model.Ui.FlirRoiWidthField.Value, model.Ui.FlirRoiHeightField.Value];
end

function helpers = uiHelpers()
helpers = struct( ...
    'createGridSplitter', @createGridSplitter, ...
    'enableScrolling', @enableScrolling, ...
    'createRightLabel', @createRightLabel);
end

function callbacks = imagingCallbacks()
names = ["refreshFlirDevices", "connectFlir", "disconnectFlir", "applyFlirExposure", "applyFlirGain", ...
    "flirRoiInputChanged", "centerFlirRoi", "applyFlirRoi", "testFlirCapture", "openFlirLiveWindow", ...
    "autoExposureChanged", "autoExposureSafetyFactorChanged", "browseImagingFolder", ...
    "setCurrentImagingEnd", "setCurrentImagingStart", ...
    "start3DImaging", "stopRequested"];
callbacks = struct();
for name = names
    callbacks.(name) = @(~, ~) [];
end
end

function appendLog(logs, message)
logs.Value(end + 1) = string(message);
end

function [flir, nodes] = fakeConnectedFlir()
sensorWidth = 4000;
sensorHeight = 3000;
offsetX = FakeGenicamIntegerNode(0, 0, 4);
offsetY = FakeGenicamIntegerNode(0, 0, 2);
width = FakeGenicamIntegerNode(sensorWidth, 16, 4);
height = FakeGenicamIntegerNode(sensorHeight, 8, 2);
offsetX.MaxFcn = @() sensorWidth - width.Value;
offsetY.MaxFcn = @() sensorHeight - height.Value;
width.MaxFcn = @() sensorWidth - offsetX.Value;
height.MaxFcn = @() sensorHeight - offsetY.Value;
widthMax = FakeGenicamIntegerNode(sensorWidth, 0, 1, @() sensorWidth);
widthMax.IsWritable = false;
heightMax = FakeGenicamIntegerNode(sensorHeight, 0, 1, @() sensorHeight);
heightMax.IsWritable = false;

nodeMap = FakeGenicamNodeMap();
nodeMap.add('OffsetX', offsetX);
nodeMap.add('OffsetY', offsetY);
nodeMap.add('Width', width);
nodeMap.add('Height', height);
nodeMap.add('WidthMax', widthMax);
nodeMap.add('HeightMax', heightMax);

nodes = struct('OffsetX', offsetX, 'OffsetY', offsetY, 'Width', width, 'Height', height);
flir = lw_flir_default_state();
flir.isConnected = true;
flir.cam = 1;
flir.nodeMap = nodeMap;
end

function deleteIfValid(handleValue)
if ~isempty(handleValue) && isvalid(handleValue)
    delete(handleValue);
end
end
