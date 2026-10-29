classdef TestFlirRoi < matlab.unittest.TestCase
    %TESTFLIRROI No-hardware tests for FLIR ROI snapping, camera writes, and persistence.

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
        function normalizeSnapsToCameraSteps(testCase)
            roi = lw_flir_normalize_roi(rect(1997.4, 687, 501, 499), bfsLimits());
            testCase.verifyEqual(rectVector(roi), [1996, 688, 500, 500]);
        end

        function normalizeKeepsRoiInsideSensor(testCase)
            roi = lw_flir_normalize_roi(rect(3900, -5, 500, 5000), bfsLimits());
            testCase.verifyEqual(rectVector(roi), [3500, 0, 500, 3000]);

            tiny = lw_flir_normalize_roi(rect(10, 10, 3, 1), bfsLimits());
            testCase.verifyEqual([tiny.Width, tiny.Height], [16, 8]);
        end

        function normalizeRejectsInvalidSizes(testCase)
            testCase.verifyError(@() lw_flir_normalize_roi(rect(0, 0, 0, 100), bfsLimits()), ...
                'lw:flir:InvalidRoi');
            testCase.verifyError(@() lw_flir_normalize_roi(rect(NaN, 0, 100, 100), bfsLimits()), ...
                'lw:flir:InvalidRoi');
        end

        function selectionNormalizesModeNames(testCase)
            testCase.verifyEqual(lw_flir_roi_selection("native", rect(0, 0, 64, 64)).Mode, "full");
            testCase.verifyEqual(lw_flir_roi_selection("top_left_quarter", rect(0, 0, 64, 64)).Mode, ...
                "top-left-quarter");
            testCase.verifyError(@() lw_flir_roi_selection("zoom", rect(0, 0, 64, 64)), 'lw:flir:InvalidRoi');
            testCase.verifyError(@() lw_flir_roi_selection("custom", rect(0.5, 0, 64, 64)), 'lw:flir:InvalidRoi');
        end

        function savedSelectionRoundTrips(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            filePath = fullfile(folder, 'settings', 'flir_roi.json');
            saved = lw_flir_roi_selection("custom", rect(1996, 686, 500, 500));
            lw_flir_roi_selection_save(filePath, saved, "1: FLIR BFS-U3-120S4M");

            fallback = lw_flir_roi_selection("full", rect(0, 0, 512, 512));
            [loaded, message] = lw_flir_roi_selection_load(filePath, fallback);
            testCase.verifyEqual(loaded, saved);
            testCase.verifyTrue(startsWith(message, "Loaded"));
        end

        function missingOrCorruptFileUsesFallback(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            fallback = lw_flir_roi_selection("top-left-quarter", rect(0, 0, 512, 512));

            [loaded, message] = lw_flir_roi_selection_load(fullfile(folder, 'missing.json'), fallback);
            testCase.verifyEqual(loaded, fallback);
            testCase.verifyEqual(message, "");

            corruptPath = fullfile(folder, 'corrupt.json');
            writeText(corruptPath, '{"Mode": "custom", "Width": -4}');
            [loaded, message] = lw_flir_roi_selection_load(corruptPath, fallback);
            testCase.verifyEqual(loaded, fallback);
            testCase.verifyTrue(contains(message, "ignored"));
        end

        function customRoiClearsOffsetsBeforeGrowing(testCase)
            % Width.Max shrinks with OffsetX, so a naive Width-first write would be clamped.
            [flir, nodes] = fakeFlir(rect(3496, 2496, 500, 500));
            [flir, width, height, roi] = lw_flir_set_custom_roi(flir, rect(0, 0, 4000, 3000));

            testCase.verifyEqual([width, height], [4000, 3000]);
            testCase.verifyEqual(rectVector(roi), [0, 0, 4000, 3000]);
            testCase.verifyEqual(roi.Name, "custom");
            testCase.verifyEqual(flir.currentRoi, roi);
            testCase.verifyEqual(nodes.OffsetX.Value, 0);
        end

        function customRoiSnapsAndReportsFullSensorSize(testCase)
            [flir, ~] = fakeFlir(rect(0, 0, 4000, 3000));
            [~, width, height, roi] = lw_flir_set_custom_roi(flir, rect(3497, 2495, 501, 499));

            testCase.verifyEqual([width, height], [500, 500]);
            testCase.verifyEqual(rectVector(roi), [3496, 2496, 500, 500]);
            testCase.verifyEqual([roi.SensorWidth, roi.SensorHeight], [4000, 3000]);
        end

        function captureRegionDispatchesCustomStruct(testCase)
            [flir, ~] = fakeFlir(rect(0, 0, 4000, 3000));
            [~, width, height, roi] = lw_flir_set_capture_region(flir, rect(1996, 686, 500, 500));
            testCase.verifyEqual([width, height], [500, 500]);
            testCase.verifyEqual(rectVector(roi), [1996, 686, 500, 500]);
        end

        function customRoiRefusesWhileAcquiring(testCase)
            [flir, ~] = fakeFlir(rect(0, 0, 4000, 3000));
            flir.isAcquiring = true;
            testCase.verifyError(@() lw_flir_set_custom_roi(flir, rect(0, 0, 500, 500)), ?MException);
        end

        function readOnlyRoiKeepsCameraValues(testCase)
            [flir, nodes] = fakeFlir(rect(1996, 686, 500, 500));
            nodes.Width.IsWritable = false;
            nodes.Height.IsWritable = false;
            [~, width, height, roi] = lw_flir_set_custom_roi(flir, rect(0, 0, 64, 64));

            testCase.verifyEqual([width, height], [500, 500]);
            testCase.verifyEqual(roi.Name, "current-read-only");
            testCase.verifyEmpty(nodes.OffsetX.Writes);
        end

        function limitsReportCameraIncrements(testCase)
            [flir, ~] = fakeFlir(rect(1996, 686, 500, 500));
            limits = lw_flir_read_roi_limits(flir.nodeMap);
            expected = bfsLimits();
            testCase.verifyEqual(limits, expected);
        end
    end
end

function value = rect(offsetX, offsetY, width, height)
value = struct('OffsetX', offsetX, 'OffsetY', offsetY, 'Width', width, 'Height', height);
end

function values = rectVector(roi)
values = [roi.OffsetX, roi.OffsetY, roi.Width, roi.Height];
end

function limits = bfsLimits()
limits = struct( ...
    'SensorWidth', 4000, ...
    'SensorHeight', 3000, ...
    'WidthMin', 16, ...
    'HeightMin', 8, ...
    'WidthIncrement', 4, ...
    'HeightIncrement', 2, ...
    'OffsetXIncrement', 4, ...
    'OffsetYIncrement', 2, ...
    'IsWritable', true);
end

function [flir, nodes] = fakeFlir(initial)
limits = bfsLimits();
sensorWidth = limits.SensorWidth;
sensorHeight = limits.SensorHeight;
offsetX = FakeGenicamIntegerNode(initial.OffsetX, 0, limits.OffsetXIncrement);
offsetY = FakeGenicamIntegerNode(initial.OffsetY, 0, limits.OffsetYIncrement);
width = FakeGenicamIntegerNode(initial.Width, limits.WidthMin, limits.WidthIncrement);
height = FakeGenicamIntegerNode(initial.Height, limits.HeightMin, limits.HeightIncrement);
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
flir = struct( ...
    'isConnected', true, ...
    'cam', 1, ...
    'isAcquiring', false, ...
    'nodeMap', nodeMap, ...
    'currentRoi', struct());
end

function writeText(filePath, text)
fileId = fopen(filePath, 'w');
cleanupObj = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', text);
clear cleanupObj
end
