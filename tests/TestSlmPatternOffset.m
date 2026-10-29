classdef TestSlmPatternOffset < matlab.unittest.TestCase
    %TESTSLMPATTERNOFFSET Whole-pattern SLM offset in SLM Control, batch rows, and metadata.

    methods (TestClassSetup)
        function addProjectPaths(~)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(refactorRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function translateMovesRightAndDownWithZeroFill(testCase)
            phase = single(reshape(1:20, 4, 5));

            moved = slm_translate_phase(phase, 2, 1);

            expected = zeros(4, 5, 'single');
            expected(2:4, 3:5) = phase(1:3, 1:3);
            testCase.verifyEqual(moved, expected);
        end

        function translateMovesLeftAndUp(testCase)
            phase = reshape(1:20, 4, 5);

            moved = slm_translate_phase(phase, -1, -2);

            expected = zeros(4, 5);
            expected(1:2, 1:4) = phase(3:4, 2:5);
            testCase.verifyEqual(moved, expected);
        end

        function zeroOffsetKeepsPatternAndFullMoveLeavesFlatPhase(testCase)
            phase = reshape(1:20, 4, 5);

            testCase.verifyEqual(slm_translate_phase(phase, 0, 0), phase);
            testCase.verifyEqual(slm_translate_phase(phase, 5, 0), zeros(4, 5));
            testCase.verifyEqual(slm_translate_phase(phase, 0, -4), zeros(4, 5));
        end

        function translateRejectsPartialPixels(testCase)
            phase = zeros(4, 5);

            testCase.verifyError(@() slm_translate_phase(phase, 0.5, 0), 'SLM:InvalidPatternOffset');
            testCase.verifyError(@() slm_translate_phase(phase, 0, NaN), 'SLM:InvalidPatternOffset');
            testCase.verifyError(@() slm_translate_phase(phase, Inf, 0), 'SLM:InvalidPatternOffset');
        end

        function batchApertureMovesWithPattern(testCase)
            pattern = struct('name', 'flat', 'phaseData', ones(40, 60, 'single'), 'phaseUnit', 2 * pi);

            centered = applyBatchGlobalAdjustments(pattern, apertureOptions(0, 0), struct());
            moved = applyBatchGlobalAdjustments(pattern, apertureOptions(7, -5), struct());

            testCase.verifyEqual(moved.phaseData, slm_translate_phase(centered.phaseData, 7, -5));
            [rows, columns] = find(moved.phaseData);
            [centeredRows, centeredColumns] = find(centered.phaseData);
            testCase.verifyEqual(mean(columns) - mean(centeredColumns), 7, 'AbsTol', 1e-9);
            testCase.verifyEqual(mean(rows) - mean(centeredRows), -5, 'AbsTol', 1e-9);
        end

        function batchRowCarriesWholePixelOffsets(testCase)
            row = batchDefaultRow(1);
            cfg = slm_config();
            testCase.verifyEqual(row{batchColumnIndex('GlobalPatternOffsetXpx')}, cfg.patternOffsetXpx);
            testCase.verifyEqual(row{batchColumnIndex('GlobalPatternOffsetYpx')}, cfg.patternOffsetYpx);

            row{batchColumnIndex('GlobalPatternOffsetXpx')} = -100;
            row{batchColumnIndex('GlobalPatternOffsetYpx')} = '80';
            job = batchJobFromDataRow(row, 1);
            testCase.verifyEqual(job.globalAdjustments.patternOffsetXpx, -100);
            testCase.verifyEqual(job.globalAdjustments.patternOffsetYpx, 80);

            row{batchColumnIndex('GlobalPatternOffsetXpx')} = 10.5;
            err = capturedError(@() batchJobFromDataRow(row, 3));
            testCase.verifySubstring(err.message, ...
                'Batch row 3 GlobalPatternOffsetXpx must be a whole number of pixels');
        end

        function batchJobShowsMovedPattern(testCase)
            row = batchDefaultRow(1);
            row{batchColumnIndex('GlobalPatternOffsetXpx')} = -9;
            row{batchColumnIndex('GlobalPatternOffsetYpx')} = 4;
            job = batchJobFromDataRow(row, 1);
            ctx = struct('widthPx', 60, 'heightPx', 40, 'config', slm_config());

            [snapshot, pattern, adjustedPattern] = batchApplySlmJob(job, ctx, false);

            testCase.verifyEqual(adjustedPattern.phaseData, slm_translate_phase(pattern.phaseData, -9, 4));
            testCase.verifyEqual([snapshot.globalAdjustments.patternOffsetXpx, ...
                snapshot.globalAdjustments.patternOffsetYpx], [-9, 4]);
        end

        function sweepNamesOffsetRows(testCase)
            testCase.verifyTrue(all(ismember({'GlobalPatternOffsetXpx', 'GlobalPatternOffsetYpx'}, ...
                batchSweepParameterItems())));

            row = batchSweepRow(batchDefaultRow(1), 2, 'scan', ...
                'GlobalPatternOffsetXpx', -100, 'GlobalPatternOffsetYpx', 80);

            testCase.verifyEqual(row{batchColumnIndex('Name')}, 'scan_002_poxm100_poy80');
            testCase.verifyEqual(row{batchColumnIndex('GlobalPatternOffsetXpx')}, -100);
            testCase.verifyEqual(row{batchColumnIndex('GlobalPatternOffsetYpx')}, 80);
        end

        function metadataRecordsPatternOffset(testCase)
            snapshot = struct('options', struct(), 'globalAdjustments', ...
                struct('patternOffsetXpx', -100, 'patternOffsetYpx', 80));
            info = struct('FrameID', 1, 'Timestamp', 2, 'PixelFormat', 'Mono8', 'Width', 64, 'Height', 48);

            row = lw_imaging_metadata_row(1, struct('x', 0, 'y', 0, 'z', 0), 0, 'stack.tif', ...
                1, info, 100, 0, NaN, snapshot);

            testCase.verifyEqual([row.SLMGlobalPatternOffsetX_px, row.SLMGlobalPatternOffsetY_px], [-100, 80]);
            testCase.verifyEqual(fieldnames(row), fieldnames(lw_empty_imaging_metadata_rows()));
        end

        function preflightListsPatternOffset(testCase)
            preflight = struct('zPositions', [0, 1], 'x', 0, 'displayY', 0, 'zStart', 0, 'zEnd', 1, ...
                'zStep', 1, 'settlingTime', 0, 'exposureUs', 100, 'gain', 0, 'captureTimeoutMs', 1000, ...
                'runFolder', 'out', 'stackFile', 'stack.tif', 'slmFilenameToken', "beta=0.4");
            preflight.slmSnapshot = struct('options', struct(), 'currentOnSlm', "drill + global", ...
                'globalAdjustments', struct('patternOffsetXpx', -100, 'patternOffsetYpx', 80));

            summaryText = lw_build_3d_imaging_preflight_summary_text(preflight, true, true);

            testCase.verifySubstring(summaryText, 'pattern offset X -100 px, Y +80 px');
        end

        function slmControlPreviewShowsMovedPattern(testCase)
            fig = lw_slm_control_app();
            testCase.addTeardown(@() closeIfValid(fig));
            setField(globalControl(fig, 'Pattern X offset px (+right)'), 7);
            setField(globalControl(fig, 'Pattern Y offset px (+down)'), -5);

            invokeButton(actionButton(fig, 'Preview'));

            testCase.verifyEqual(previewImage(fig, 'Global:'), ...
                slm_translate_phase(previewImage(fig, 'Base:'), 7, -5));
            snapshot = getappdata(0, 'LaserWritingCurrentSlmDrillOptions');
            testCase.verifyEqual([snapshot.globalAdjustments.patternOffsetXpx, ...
                snapshot.globalAdjustments.patternOffsetYpx], [7, -5]);
        end

        function offsetControlsSnapToWholePixels(testCase)
            fig = lw_slm_control_app();
            testCase.addTeardown(@() closeIfValid(fig));
            [field, slider] = globalControl(fig, 'Pattern X offset px (+right)');

            slider.ValueChangingFcn(slider, struct('Value', 12.4));
            testCase.verifyEqual(field.Value, 12);
            slider.Value = 12.6;
            slider.ValueChangedFcn(slider, []);
            testCase.verifyEqual([field.Value, slider.Value], [13, 13]);

            tabGroup = findall(fig, 'Type', 'uitabgroup');
            tabGroup.SelectedTab = findall(fig, 'Type', 'uitab', 'Title', 'Global Adjustments');
            fig.WindowKeyPressFcn(fig, struct('Key', 'rightarrow'));
            testCase.verifyEqual([field.Value, slider.Value], [14, 14]);
        end
    end
end

function options = apertureOptions(offsetXpx, offsetYpx)
options = struct( ...
    'lensFocalLengthMm', 0, ...
    'xShiftTwoPi', 0, ...
    'yShiftTwoPi', 0, ...
    'apertureRadiusPx', 6, ...
    'apertureCenterXpx', 0, ...
    'apertureCenterYpx', 0, ...
    'patternOffsetXpx', offsetXpx, ...
    'patternOffsetYpx', offsetYpx);
end

function [field, slider] = globalControl(fig, labelText)
label = findall(fig, 'Type', 'uilabel', 'Text', labelText);
field = [];
slider = [];
for control = reshape(label.Parent.Children, 1, [])
    if ~isequal(control.Layout.Row, label.Layout.Row)
        continue;
    end
    if isa(control, 'matlab.ui.control.NumericEditField')
        field = control;
    elseif isa(control, 'matlab.ui.control.Slider')
        slider = control;
    end
end
end

function setField(field, value)
field.Value = value;
field.ValueChangedFcn(field, []);
drawnow;
end

function button = actionButton(fig, buttonText)
panel = findall(fig, 'Type', 'uipanel', 'Title', 'Actions');
button = findall(panel, 'Type', 'uibutton', 'Text', buttonText);
end

function invokeButton(button)
callback = button.ButtonPushedFcn;
callback(button, []);
drawnow;
end

function data = previewImage(fig, titlePrefix)
data = [];
for axesHandle = reshape(findall(fig, 'Type', 'axes'), 1, [])
    if startsWith(string(axesHandle.Title.String), titlePrefix)
        imageHandle = findobj(axesHandle, 'Type', 'image');
        data = imageHandle.CData;
        return;
    end
end
end

function err = capturedError(action)
err = MException('TestSlmPatternOffset:NoError', 'The action did not fail.');
try
    action();
catch caught
    err = caught;
end
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
