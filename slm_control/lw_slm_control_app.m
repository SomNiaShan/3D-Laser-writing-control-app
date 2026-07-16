function fig = lw_slm_control_app()
%LW_SLM_CONTROL_APP Button-based MATLAB UI for controlling the HOLOEYE SLM.

localAddRepoPaths();

state = struct();
state.cfg = slm_config();
state.ctx = [];
state.currentPattern = [];
state.currentAdjustedPattern = [];
state.currentOnSlm = 'none';
state.embeddedPreviewTimer = [];
state.embeddedPreviewFile = fullfile(tempdir, 'slm_control_app_sdk_preview.png');
state.activeGlobalControlIndex = [];
state.isSyncingAxiconControls = false;
noPatternListItem = '(no saved patterns)';
noGlobalAdjustmentListItem = '(no saved adjustments)';
globalControlRows = struct('label', {}, 'field', {}, 'slider', {}, 'step', {}, 'name', {});
drillDefaults = slm_default_drill_beam_options();
slmSnapshotAppDataKey = 'LaserWritingCurrentSlmDrillOptions';

fig = uifigure( ...
    'Name', 'SLM MATLAB Control (Laser Writing)', ...
    'Position', [100 100 1060 720], ...
    'CloseRequestFcn', @onClose, ...
    'WindowButtonDownFcn', @onWindowButtonDown, ...
    'WindowKeyPressFcn', @onWindowKeyPress);

main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {420, '1x'};
main.RowHeight = {'1x'};
main.Padding = [12 12 12 12];
main.ColumnSpacing = 12;

leftTabs = uitabgroup(main);
leftTabs.Layout.Row = 1;
leftTabs.Layout.Column = 1;
mainTab = uitab(leftTabs, 'Title', 'Main');
globalTab = uitab(leftTabs, 'Title', 'Global Adjustments');
diagnosticsTab = uitab(leftTabs, 'Title', 'Diagnostics');

mainControlsGrid = uigridlayout(mainTab, [4 1]);
mainControlsGrid.RowHeight = {150, '1x', 70, 180};
mainControlsGrid.Padding = [10 10 10 10];
mainControlsGrid.RowSpacing = 10;

connectionPanel = uipanel(mainControlsGrid, 'Title', 'Connection');
connectionPanel.Layout.Row = 1;
connectionGrid = uigridlayout(connectionPanel, [3 1]);
connectionGrid.RowHeight = {42, 22, 22};
connectionGrid.Padding = [10 8 10 8];
connectionGrid.RowSpacing = 8;

connectButton = uibutton(connectionGrid, 'Text', 'Connect SLM', 'ButtonPushedFcn', @onToggleConnection);
connectButton.Layout.Row = 1;
connectButton.FontWeight = 'bold';
statusLabel = uilabel(connectionGrid, 'Text', 'Status: disconnected', 'FontWeight', 'bold');
statusLabel.Layout.Row = 2;
currentOnSlmLabel = uilabel(connectionGrid, 'Text', 'Current on SLM: none', 'FontWeight', 'bold');
currentOnSlmLabel.Layout.Row = 3;

drillPanel = uipanel(mainControlsGrid, 'Title', 'Bessel Beam generator');
drillPanel.Layout.Row = 2;
drillGrid = uigridlayout(drillPanel, [14 2], 'Scrollable', 'on');
drillGrid.RowHeight = repmat({30}, 1, 14);
drillGrid.ColumnWidth = {185, '1x'};
drillGrid.Padding = [10 8 10 8];
drillGrid.RowSpacing = 6;

nameField = addTextField(drillGrid, 1, 'Pattern name', 'drill_helical_custom');
axiconModeLabel = uilabel(drillGrid, 'Text', 'Axicon definition');
setGridLocation(axiconModeLabel, 2, 1);
axiconModeDropDown = uidropdown(drillGrid, ...
    'Items', axiconModeOptions(), ...
    'Value', drillDefaults.axiconMode, ...
    'ValueChangedFcn', @onAxiconModeChanged);
setGridLocation(axiconModeDropDown, 2, 2);
axiconConeAngleField = addNumericField(drillGrid, 3, 'Cone angle beta (deg)', ...
    drillDefaults.axiconConeAngleDeg, [-Inf Inf], false);
axiconRadialPeriodMmField = addNumericField(drillGrid, 4, 'Radial period (mm)', ...
    drillDefaults.axiconRadialPeriodMm, [-Inf Inf], false);
axiconRadialPeriodPxField = addNumericField(drillGrid, 5, 'Radial period (px)', ...
    drillDefaults.axiconRadialPeriodPx, [-Inf Inf], false);
axiconRadialCyclesField = addNumericField(drillGrid, 6, 'Radial cycles (rho)', ...
    drillDefaults.axiconRadialCycles, [-Inf Inf], false);
axiconIndexField = addNumericField(drillGrid, 7, 'Axicon refractive index (n)', ...
    drillDefaults.axiconIndex, [0 Inf], false);
axiconPhysicalBaseAngleField = addNumericField(drillGrid, 8, 'Physical base angle alpha (deg)', ...
    drillDefaults.axiconPhysicalBaseAngleDeg, [-Inf Inf], false);
axiconConeAngleField.ValueChangedFcn = @onAxiconParameterChanged;
axiconRadialPeriodMmField.ValueChangedFcn = @onAxiconParameterChanged;
axiconRadialPeriodPxField.ValueChangedFcn = @onAxiconParameterChanged;
axiconRadialCyclesField.ValueChangedFcn = @onAxiconParameterChanged;
axiconIndexField.ValueChangedFcn = @onAxiconParameterChanged;
axiconPhysicalBaseAngleField.ValueChangedFcn = @onAxiconParameterChanged;
vortexField = addNumericField(drillGrid, 9, 'Vortex charge', 0, [-Inf Inf], true);
helicalGammaField = addNumericField(drillGrid, 10, 'Helical gamma', 1, [-Inf Inf], false);
helicalOrderField = addNumericField(drillGrid, 11, 'Helical order', 1, [-Inf Inf], true);
helicalOffsetField = addNumericField(drillGrid, 12, 'Helical offset deg', 0, [-Inf Inf], false);
omegaInnerField = addNumericField(drillGrid, 13, 'Omega inner', 10, [-Inf Inf], false);
omegaOuterField = addNumericField(drillGrid, 14, 'Omega outer', 10, [-Inf Inf], false);
nameField.ValueChangedFcn = @onDrillOptionChanged;
vortexField.ValueChangedFcn = @onDrillOptionChanged;
helicalGammaField.ValueChangedFcn = @onDrillOptionChanged;
helicalOrderField.ValueChangedFcn = @onDrillOptionChanged;
helicalOffsetField.ValueChangedFcn = @onDrillOptionChanged;
omegaInnerField.ValueChangedFcn = @onDrillOptionChanged;
omegaOuterField.ValueChangedFcn = @onDrillOptionChanged;

actionsPanel = uipanel(mainControlsGrid, 'Title', 'Actions');
actionsPanel.Layout.Row = 3;
actionsGrid = uigridlayout(actionsPanel, [1 3]);
actionsGrid.ColumnWidth = {'1x', '1x', '1x'};
actionsGrid.Padding = [10 8 10 8];
actionsGrid.ColumnSpacing = 8;

generatePreviewButton = uibutton(actionsGrid, 'Text', 'Preview', ...
    'ButtonPushedFcn', @onGeneratePreview);
generatePreviewButton.Layout.Column = 1;
generateShowButton = uibutton(actionsGrid, 'Text', 'Show on SLM', ...
    'ButtonPushedFcn', @onGenerateShow);
generateShowButton.Layout.Column = 2;
saveCurrentButton = uibutton(actionsGrid, 'Text', 'Save', 'ButtonPushedFcn', @onSaveCurrent);
saveCurrentButton.Layout.Column = 3;

savedPanel = uipanel(mainControlsGrid, 'Title', 'Saved Patterns');
savedPanel.Layout.Row = 4;
savedGrid = uigridlayout(savedPanel, [2 4]);
savedGrid.RowHeight = {'1x', 34};
savedGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
savedGrid.Padding = [10 8 10 8];
savedGrid.RowSpacing = 8;
savedGrid.ColumnSpacing = 8;

patternItems = cellstr(slm_list_patterns(state.cfg));
if isempty(patternItems)
    patternItems = {noPatternListItem};
end
patternListBox = uilistbox(savedGrid, 'Items', patternItems, 'Value', patternItems{1});
patternListBox.Layout.Row = 1;
patternListBox.Layout.Column = [1 4];

previewSelectedButton = uibutton(savedGrid, 'Text', 'Preview', ...
    'ButtonPushedFcn', @onPreviewSelectedPattern);
setGridLocation(previewSelectedButton, 2, 1);
showSelectedButton = uibutton(savedGrid, 'Text', 'Show', ...
    'ButtonPushedFcn', @onShowSelectedPattern);
setGridLocation(showSelectedButton, 2, 2);
deleteSelectedButton = uibutton(savedGrid, 'Text', 'Delete', ...
    'ButtonPushedFcn', @onDeleteSelectedPattern);
setGridLocation(deleteSelectedButton, 2, 3);
refreshListButton = uibutton(savedGrid, 'Text', 'Refresh', 'ButtonPushedFcn', @onRefreshPatterns);
setGridLocation(refreshListButton, 2, 4);
if strcmp(patternItems{1}, noPatternListItem)
    previewSelectedButton.Enable = 'off';
    showSelectedButton.Enable = 'off';
    deleteSelectedButton.Enable = 'off';
end

globalControlsGrid = uigridlayout(globalTab, [2 1]);
globalControlsGrid.RowHeight = {330, '1x'};
globalControlsGrid.Padding = [10 10 10 10];
globalControlsGrid.RowSpacing = 10;

globalPanel = uipanel(globalControlsGrid, 'Title', 'Global Adjustments');
globalPanel.Layout.Row = 1;
globalGrid = uigridlayout(globalPanel, [7 3], 'Scrollable', 'on');
globalGrid.RowHeight = [repmat({42}, 1, 6), {34}];
globalGrid.ColumnWidth = {185, 72, '1x'};
globalGrid.Padding = [10 8 10 8];
globalGrid.RowSpacing = 6;

globalApertureMaxPx = ceil(hypot(state.cfg.expectedWidthPx, state.cfg.expectedHeightPx) / 2);
globalHalfWidthPx = state.cfg.expectedWidthPx / 2;
globalHalfHeightPx = state.cfg.expectedHeightPx / 2;

[globalLensField, globalLensSlider] = addSliderNumericField(globalGrid, 1, ...
    'Lens focal mm (0 off)', 0, [-Inf Inf], [-1000 1000], 1);
[globalXShiftField, globalXShiftSlider] = addSliderNumericField(globalGrid, 2, ...
    ['X shift 2' char(960) ' (0 off)'], 0, [-Inf Inf], [-state.cfg.expectedWidthPx state.cfg.expectedWidthPx], 1);
[globalYShiftField, globalYShiftSlider] = addSliderNumericField(globalGrid, 3, ...
    ['Y shift 2' char(960) ' (0 off)'], 0, [-Inf Inf], [-state.cfg.expectedHeightPx state.cfg.expectedHeightPx], 1);
[globalApertureRadiusField, globalApertureRadiusSlider] = addSliderNumericField(globalGrid, 4, ...
    'Aperture radius px (0 full)', 0, [0 Inf], [0 globalApertureMaxPx], 1);
[globalApertureCenterXField, globalApertureCenterXSlider] = addSliderNumericField(globalGrid, 5, ...
    'Aperture X center px', 0, [-Inf Inf], [-globalHalfWidthPx globalHalfWidthPx], 1);
[globalApertureCenterYField, globalApertureCenterYSlider] = addSliderNumericField(globalGrid, 6, ...
    'Aperture Y center px', 0, [-Inf Inf], [-globalHalfHeightPx globalHalfHeightPx], 1);
resetGlobalButton = uibutton(globalGrid, 'Text', 'Reset', ...
    'ButtonPushedFcn', @onResetGlobalAdjustments);
setGridLocation(resetGlobalButton, 7, [1 3]);

globalPresetPanel = uipanel(globalControlsGrid, 'Title', 'Saved Global Adjustments');
globalPresetPanel.Layout.Row = 2;
globalPresetGrid = uigridlayout(globalPresetPanel, [3 4]);
globalPresetGrid.RowHeight = {30, '1x', 34};
globalPresetGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
globalPresetGrid.Padding = [10 8 10 8];
globalPresetGrid.RowSpacing = 8;
globalPresetGrid.ColumnSpacing = 8;

globalPresetNameLabel = uilabel(globalPresetGrid, 'Text', 'Name');
setGridLocation(globalPresetNameLabel, 1, 1);
globalAdjustmentNameField = uieditfield(globalPresetGrid, 'text', ...
    'Value', 'global_adjustment_custom');
setGridLocation(globalAdjustmentNameField, 1, [2 4]);

globalAdjustmentItems = cellstr(slm_list_global_adjustments(state.cfg));
if isempty(globalAdjustmentItems)
    globalAdjustmentItems = {noGlobalAdjustmentListItem};
end
globalAdjustmentListBox = uilistbox(globalPresetGrid, ...
    'Items', globalAdjustmentItems, ...
    'Value', globalAdjustmentItems{1}, ...
    'ValueChangedFcn', @onGlobalAdjustmentSelectionChanged);
globalAdjustmentListBox.Layout.Row = 2;
globalAdjustmentListBox.Layout.Column = [1 4];

saveGlobalAdjustmentButton = uibutton(globalPresetGrid, 'Text', 'Save', ...
    'ButtonPushedFcn', @onSaveGlobalAdjustment);
setGridLocation(saveGlobalAdjustmentButton, 3, 1);
applyGlobalAdjustmentButton = uibutton(globalPresetGrid, 'Text', 'Apply', ...
    'ButtonPushedFcn', @onApplySelectedGlobalAdjustment);
setGridLocation(applyGlobalAdjustmentButton, 3, 2);
deleteGlobalAdjustmentButton = uibutton(globalPresetGrid, 'Text', 'Delete', ...
    'ButtonPushedFcn', @onDeleteSelectedGlobalAdjustment);
setGridLocation(deleteGlobalAdjustmentButton, 3, 3);
refreshGlobalAdjustmentButton = uibutton(globalPresetGrid, 'Text', 'Refresh', ...
    'ButtonPushedFcn', @onRefreshGlobalAdjustments);
setGridLocation(refreshGlobalAdjustmentButton, 3, 4);
if strcmp(globalAdjustmentItems{1}, noGlobalAdjustmentListItem)
    applyGlobalAdjustmentButton.Enable = 'off';
    deleteGlobalAdjustmentButton.Enable = 'off';
else
    globalAdjustmentNameField.Value = globalAdjustmentItems{1};
end

diagnosticsGrid = uigridlayout(diagnosticsTab, [2 1]);
diagnosticsGrid.RowHeight = {110, '1x'};
diagnosticsGrid.Padding = [10 10 10 10];
diagnosticsGrid.RowSpacing = 10;

sdkPanel = uipanel(diagnosticsGrid, 'Title', 'SDK Preview');
sdkPanel.Layout.Row = 1;
sdkGrid = uigridlayout(sdkPanel, [2 3]);
sdkGrid.ColumnWidth = {'1x', '1x', '1x'};
sdkGrid.Padding = [10 8 10 8];
sdkGrid.RowSpacing = 8;
sdkGrid.ColumnSpacing = 8;

openSdkPreviewButton = uibutton(sdkGrid, 'Text', 'Open', ...
    'ButtonPushedFcn', @onOpenSdkPreview);
setGridLocation(openSdkPreviewButton, 1, 1);
moveSdkPreviewButton = uibutton(sdkGrid, 'Text', 'Move', ...
    'ButtonPushedFcn', @onMoveSdkPreview);
setGridLocation(moveSdkPreviewButton, 1, 2);
closeSdkPreviewButton = uibutton(sdkGrid, 'Text', 'Close', ...
    'ButtonPushedFcn', @onCloseSdkPreview);
setGridLocation(closeSdkPreviewButton, 1, 3);
startEmbeddedPreviewButton = uibutton(sdkGrid, 'Text', 'Start In-App', ...
    'ButtonPushedFcn', @onStartEmbeddedPreview);
setGridLocation(startEmbeddedPreviewButton, 2, [1 2]);
stopEmbeddedPreviewButton = uibutton(sdkGrid, 'Text', 'Stop In-App', ...
    'ButtonPushedFcn', @onStopEmbeddedPreview);
setGridLocation(stopEmbeddedPreviewButton, 2, 3);

livePanel = uipanel(diagnosticsGrid, 'Title', 'Live SDK Preview');
livePanel.Layout.Row = 2;
liveGrid = uigridlayout(livePanel, [1 1]);
liveGrid.Padding = [8 8 8 8];

liveAxes = uiaxes(liveGrid);
liveAxes.Layout.Row = 1;
title(liveAxes, 'Live SDK Preview');
axis(liveAxes, 'image');
liveAxes.XTick = [];
liveAxes.YTick = [];
colormap(liveAxes, gray(256));

previewPanel = uipanel(main, 'Title', 'Generated Pattern Preview');
previewPanel.Layout.Row = 1;
previewPanel.Layout.Column = 2;
previewGrid = uigridlayout(previewPanel, [4 1]);
previewGrid.RowHeight = {30, '1x', '1x', 120};
previewGrid.Padding = [10 10 10 10];
previewGrid.RowSpacing = 8;

previewModeGrid = uigridlayout(previewGrid, [1 2]);
previewModeGrid.Layout.Row = 1;
previewModeGrid.ColumnWidth = {110, '1x'};
previewModeGrid.Padding = [0 0 0 0];
previewModeGrid.ColumnSpacing = 8;
previewModeLabel = uilabel(previewModeGrid, 'Text', 'Preview mode');
previewModeLabel.Layout.Row = 1;
previewModeLabel.Layout.Column = 1;
previewModeDropDown = uidropdown(previewModeGrid, ...
    'Items', {'Wrapped SLM phase', 'Raw helical phase'}, ...
    'Value', 'Wrapped SLM phase', ...
    'ValueChangedFcn', @onPreviewModeChanged);
previewModeDropDown.Layout.Row = 1;
previewModeDropDown.Layout.Column = 2;

basePreviewAxes = uiaxes(previewGrid);
basePreviewAxes.Layout.Row = 2;
title(basePreviewAxes, 'Base Pattern');
axis(basePreviewAxes, 'image');
basePreviewAxes.XTick = [];
basePreviewAxes.YTick = [];
colormap(basePreviewAxes, gray(256));

adjustedPreviewAxes = uiaxes(previewGrid);
adjustedPreviewAxes.Layout.Row = 3;
title(adjustedPreviewAxes, 'With Global Adjustments');
axis(adjustedPreviewAxes, 'image');
adjustedPreviewAxes.XTick = [];
adjustedPreviewAxes.YTick = [];
colormap(adjustedPreviewAxes, gray(256));

logArea = uitextarea(previewGrid, 'Editable', 'off');
logArea.Layout.Row = 4;
logArea.Value = {'Ready.'};

updateAxiconControlStates();
syncAxiconEquivalentControls();
updateConnectionStatus();
publishCurrentDrillOptions();
logMessage('App opened.');

    function field = addNumericField(parent, row, labelText, value, limits, roundValues)
        label = uilabel(parent, 'Text', labelText);
        setGridLocation(label, row, 1);
        field = uieditfield(parent, 'numeric', 'Value', value, 'Limits', limits, ...
            'RoundFractionalValues', roundValues);
        setGridLocation(field, row, 2);
    end

    function field = addTextField(parent, row, labelText, value)
        label = uilabel(parent, 'Text', labelText);
        setGridLocation(label, row, 1);
        field = uieditfield(parent, 'text', 'Value', value);
        setGridLocation(field, row, 2);
    end

    function [field, slider] = addSliderNumericField(parent, row, labelText, value, fieldLimits, sliderLimits, step)
        label = uilabel(parent, 'Text', labelText);
        setGridLocation(label, row, 1);

        field = uieditfield(parent, 'numeric', 'Value', value, 'Limits', fieldLimits, ...
            'RoundFractionalValues', false);
        setGridLocation(field, row, 2);

        slider = uislider(parent, 'Limits', sliderLimits, ...
            'Value', clampSliderValue(value, sliderLimits), ...
            'MajorTicks', [], ...
            'MinorTicks', []);
        setGridLocation(slider, row, 3);

        controlIndex = registerGlobalControl(label, field, slider, step, labelText);
        field.ValueChangedFcn = @(~, ~) onGlobalFieldChanged(field, slider, controlIndex);
        slider.ValueChangingFcn = @(~, event) onGlobalSliderChanging(event, field, controlIndex);
        slider.ValueChangedFcn = @(~, ~) onGlobalSliderChanged(slider, field, controlIndex);
    end

    function controlIndex = registerGlobalControl(label, field, slider, step, name)
        controlIndex = numel(globalControlRows) + 1;
        globalControlRows(controlIndex).label = label;
        globalControlRows(controlIndex).field = field;
        globalControlRows(controlIndex).slider = slider;
        globalControlRows(controlIndex).step = step;
        globalControlRows(controlIndex).name = name;
    end

    function onGlobalFieldChanged(field, slider, controlIndex)
        setActiveGlobalControl(controlIndex);
        slider.Value = clampSliderValue(field.Value, slider.Limits);
        onGlobalAdjustmentChanged([], []);
    end

    function onGlobalSliderChanging(event, field, controlIndex)
        setActiveGlobalControl(controlIndex);
        field.Value = event.Value;
    end

    function onGlobalSliderChanged(slider, field, controlIndex)
        setActiveGlobalControl(controlIndex);
        field.Value = slider.Value;
        onGlobalAdjustmentChanged([], []);
    end

    function onWindowButtonDown(~, ~)
        controlIndex = globalControlIndexFromObject(fig.CurrentObject);
        if ~isempty(controlIndex)
            setActiveGlobalControl(controlIndex);
        end
    end

    function onWindowKeyPress(~, event)
        if ~isequal(leftTabs.SelectedTab, globalTab)
            return;
        end
        switch lower(event.Key)
            case 'rightarrow'
                adjustActiveGlobalControl(1, eventStepMultiplier(event));
            case 'leftarrow'
                adjustActiveGlobalControl(-1, eventStepMultiplier(event));
        end
    end

    function adjustActiveGlobalControl(direction, multiplier)
        controlIndex = state.activeGlobalControlIndex;
        if isempty(controlIndex) || controlIndex < 1 || controlIndex > numel(globalControlRows)
            return;
        end

        control = globalControlRows(controlIndex);
        nextValue = control.field.Value + direction * control.step * multiplier;
        nextValue = clampSliderValue(nextValue, control.slider.Limits);
        control.field.Value = nextValue;
        control.slider.Value = nextValue;
        onGlobalAdjustmentChanged([], []);
    end

    function multiplier = eventStepMultiplier(event)
        multiplier = 1;
        if isprop(event, 'Modifier') && ~isempty(event.Modifier)
            modifiers = string(event.Modifier);
            if any(modifiers == "shift")
                multiplier = multiplier * 10;
            end
            if any(modifiers == "control") || any(modifiers == "command")
                multiplier = multiplier * 0.1;
            end
        end
    end

    function controlIndex = globalControlIndexFromObject(component)
        controlIndex = [];
        if isempty(component)
            return;
        end
        for index = 1:numel(globalControlRows)
            row = globalControlRows(index);
            if isequal(component, row.label) || isequal(component, row.field) || ...
                    isequal(component, row.slider)
                controlIndex = index;
                return;
            end
        end
    end

    function setActiveGlobalControl(controlIndex)
        if isempty(controlIndex) || controlIndex < 1 || controlIndex > numel(globalControlRows)
            return;
        end
        state.activeGlobalControlIndex = controlIndex;
        for index = 1:numel(globalControlRows)
            if index == controlIndex
                globalControlRows(index).label.FontWeight = 'bold';
            else
                globalControlRows(index).label.FontWeight = 'normal';
            end
        end
    end

    function sliderValue = clampSliderValue(value, limits)
        if isempty(value) || isnan(value)
            sliderValue = min(max(0, limits(1)), limits(2));
            return;
        end
        if value == Inf
            sliderValue = limits(2);
            return;
        end
        if value == -Inf
            sliderValue = limits(1);
            return;
        end
        sliderValue = min(max(value, limits(1)), limits(2));
    end

    function setGridLocation(component, row, column)
        component.Layout.Row = row;
        component.Layout.Column = column;
    end

    function options = axiconModeOptions()
        options = {'coneAngle', 'radialPeriodMm', 'radialPeriodPx', 'radialCycles', 'physicalEquivalent'};
    end

    function onAxiconModeChanged(~, ~)
        updateAxiconControlStates();
        syncAxiconEquivalentControls();
        publishCurrentDrillOptions();
    end

    function onAxiconParameterChanged(~, ~)
        syncAxiconEquivalentControls();
        publishCurrentDrillOptions();
    end

    function onDrillOptionChanged(~, ~)
        publishCurrentDrillOptions();
    end

    function updateAxiconControlStates()
        mode = char(string(axiconModeDropDown.Value));
        axiconFields = {axiconConeAngleField, axiconRadialPeriodMmField, ...
            axiconRadialPeriodPxField, axiconRadialCyclesField, ...
            axiconIndexField, axiconPhysicalBaseAngleField};
        for index = 1:numel(axiconFields)
            axiconFields{index}.Enable = 'off';
        end

        switch mode
            case 'coneAngle'
                axiconConeAngleField.Enable = 'on';
            case 'radialPeriodMm'
                axiconRadialPeriodMmField.Enable = 'on';
            case 'radialPeriodPx'
                axiconRadialPeriodPxField.Enable = 'on';
            case 'radialCycles'
                axiconRadialCyclesField.Enable = 'on';
            case 'physicalEquivalent'
                axiconIndexField.Enable = 'on';
                axiconPhysicalBaseAngleField.Enable = 'on';
        end
    end

    function syncAxiconEquivalentControls()
        if state.isSyncingAxiconControls
            return;
        end

        state.isSyncingAxiconControls = true;
        cleanup = onCleanup(@() clearAxiconSyncFlag());
        try
            mode = char(string(axiconModeDropDown.Value));
            wavelengthMm = double(state.cfg.wavelengthNm) * 1e-6;
            pixelPitchMm = double(state.cfg.pixelPitchUm) * 1e-3;
            axiconReferenceRadiusMm = currentAxiconReferenceRadiusMm(pixelPitchMm);
            backgroundIndex = double(drillDefaults.backgroundIndex);
            axiconIndex = double(axiconIndexField.Value);
            if wavelengthMm <= 0 || pixelPitchMm <= 0 || axiconReferenceRadiusMm <= 0 || ...
                    backgroundIndex <= 0 || axiconIndex <= 0
                return;
            end

            kBackground = 2 * pi * backgroundIndex / wavelengthMm;
            [coneAngleRad, krRadPerMm] = resolveAxiconControlsToConeAndKr( ...
                mode, kBackground, pixelPitchMm, axiconReferenceRadiusMm);
            if ~isfinite(coneAngleRad) || ~isfinite(krRadPerMm) || ...
                    abs(coneAngleRad) >= pi / 2 || abs(krRadPerMm) >= kBackground
                return;
            end

            coneAngleDeg = rad2deg(coneAngleRad);
            radialPeriodMm = 2 * pi / krRadPerMm;
            radialPeriodPx = radialPeriodMm / pixelPitchMm;
            radialCycles = krRadPerMm * axiconReferenceRadiusMm / (2 * pi);
            physicalBaseAngleDeg = equivalentPhysicalBaseAngleDeg(coneAngleRad, axiconIndex, backgroundIndex);

            setAxiconEquivalentValue(axiconConeAngleField, coneAngleDeg, mode, 'coneAngle');
            setAxiconEquivalentValue(axiconRadialPeriodMmField, radialPeriodMm, mode, 'radialPeriodMm');
            setAxiconEquivalentValue(axiconRadialPeriodPxField, radialPeriodPx, mode, 'radialPeriodPx');
            setAxiconEquivalentValue(axiconRadialCyclesField, radialCycles, mode, 'radialCycles');
            if ~strcmp(mode, 'physicalEquivalent') && isfinite(physicalBaseAngleDeg)
                axiconPhysicalBaseAngleField.Value = physicalBaseAngleDeg;
            end
        catch
        end
        clear cleanup;
    end

    function clearAxiconSyncFlag()
        state.isSyncingAxiconControls = false;
    end

    function [coneAngleRad, krRadPerMm] = resolveAxiconControlsToConeAndKr(mode, kBackground, pixelPitchMm, axiconReferenceRadiusMm)
        switch mode
            case 'coneAngle'
                coneAngleRad = deg2rad(double(axiconConeAngleField.Value));
                krRadPerMm = kBackground * sin(coneAngleRad);
            case 'radialPeriodMm'
                radialPeriodMm = double(axiconRadialPeriodMmField.Value);
                if radialPeriodMm == 0
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                krRadPerMm = 2 * pi / radialPeriodMm;
                sinConeAngle = krRadPerMm / kBackground;
                if abs(sinConeAngle) > 1
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                coneAngleRad = asin(sinConeAngle);
            case 'radialPeriodPx'
                radialPeriodPx = double(axiconRadialPeriodPxField.Value);
                if radialPeriodPx == 0
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                radialPeriodMm = radialPeriodPx * pixelPitchMm;
                krRadPerMm = 2 * pi / radialPeriodMm;
                sinConeAngle = krRadPerMm / kBackground;
                if abs(sinConeAngle) > 1
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                coneAngleRad = asin(sinConeAngle);
            case 'radialCycles'
                radialCycles = double(axiconRadialCyclesField.Value);
                if ~isfinite(radialCycles)
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                krRadPerMm = 2 * pi * radialCycles / axiconReferenceRadiusMm;
                sinConeAngle = krRadPerMm / kBackground;
                if abs(sinConeAngle) > 1
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                coneAngleRad = asin(sinConeAngle);
            case 'physicalEquivalent'
                backgroundIndex = double(drillDefaults.backgroundIndex);
                axiconIndex = double(axiconIndexField.Value);
                physicalBaseAngleRad = deg2rad(double(axiconPhysicalBaseAngleField.Value));
                snellArgument = (axiconIndex / backgroundIndex) * sin(physicalBaseAngleRad);
                if abs(snellArgument) > 1
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
                    return;
                end
                coneAngleRad = asin(snellArgument) - ...
                    physicalBaseAngleRad;
                krRadPerMm = kBackground * sin(coneAngleRad);
            otherwise
                coneAngleRad = NaN;
                krRadPerMm = NaN;
        end
    end

    function radiusMm = currentAxiconReferenceRadiusMm(pixelPitchMm)
        widthPx = state.cfg.expectedWidthPx;
        heightPx = state.cfg.expectedHeightPx;
        if ~isempty(state.ctx) && isfield(state.ctx, 'widthPx') && isfield(state.ctx, 'heightPx')
            widthPx = state.ctx.widthPx;
            heightPx = state.ctx.heightPx;
        end
        radiusMm = (min(double(widthPx), double(heightPx)) / 2) * double(pixelPitchMm);
    end

    function baseAngleDeg = equivalentPhysicalBaseAngleDeg(coneAngleRad, axiconIndex, backgroundIndex)
        indexRatio = axiconIndex / backgroundIndex;
        denominator = indexRatio - cos(coneAngleRad);
        if denominator <= 0
            baseAngleDeg = NaN;
            return;
        end
        baseAngleDeg = rad2deg(atan2(sin(coneAngleRad), denominator));
    end

    function setAxiconEquivalentValue(field, value, currentMode, fieldMode)
        if ~strcmp(currentMode, fieldMode) && ~isnan(value)
            field.Value = value;
        end
    end

    function requireConnection()
        if isempty(state.ctx)
            error('SLM:NotConnected', 'Click "Connect SLM" first.');
        end
    end

    function onToggleConnection(~, ~)
        if isempty(state.ctx)
            onConnect([], []);
        else
            onDisconnect([], []);
        end
    end

    function onConnect(~, ~)
        try
            if isempty(state.ctx)
                state.ctx = slm_init(state.cfg);
                logMessage(sprintf('Connected SLM: %d x %d px, wavelength %.1f nm.', ...
                    state.ctx.widthPx, state.ctx.heightPx, state.ctx.config.wavelengthNm));
            else
                logMessage('SLM is already connected.');
            end
            updateConnectionStatus();
            publishCurrentDrillOptions();
        catch err
            showError(err);
        end
    end

    function onDisconnect(~, ~)
        try
            if ~isempty(state.ctx)
                stopEmbeddedPreview(false);
                slm_close(state.ctx);
                state.ctx = [];
                updateCurrentOnSlm('none');
                logMessage('SLM closed.');
            else
                logMessage('SLM was not connected.');
            end
            updateConnectionStatus();
            publishCurrentDrillOptions();
        catch err
            showError(err);
        end
    end

    function onStartEmbeddedPreview(~, ~)
        try
            requireConnection();
            slm_open_sdk_preview(state.ctx, state.cfg.previewScale);
            if isempty(state.embeddedPreviewTimer) || ~isvalid(state.embeddedPreviewTimer)
                state.embeddedPreviewTimer = timer( ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'Period', 0.5, ...
                    'BusyMode', 'drop', ...
                    'TimerFcn', @updateEmbeddedSdkPreview);
            end
            if strcmp(state.embeddedPreviewTimer.Running, 'off')
                start(state.embeddedPreviewTimer);
            end
            updateEmbeddedSdkPreview([], []);
            logMessage('In-app SDK Preview started.');
        catch err
            showError(err);
        end
    end

    function onStopEmbeddedPreview(~, ~)
        stopEmbeddedPreview(true);
    end

    function onOpenSdkPreview(~, ~)
        try
            requireConnection();
            slm_open_sdk_preview(state.ctx, state.cfg.previewScale);
            logMessage('SDK Preview opened.');
        catch err
            showError(err);
        end
    end

    function onMoveSdkPreview(~, ~)
        try
            requireConnection();
            slm_open_sdk_preview(state.ctx, state.cfg.previewScale);
            slm_move_sdk_preview(state.ctx, 2, 2, 0, 0, 60);
            logMessage('SDK Preview moved to a secondary-monitor tile.');
        catch err
            showError(err);
        end
    end

    function onCloseSdkPreview(~, ~)
        try
            requireConnection();
            stopEmbeddedPreview(false);
            slm_close_sdk_preview(state.ctx);
            logMessage('SDK Preview closed.');
        catch err
            showError(err);
        end
    end

    function stopEmbeddedPreview(writeLog)
        if nargin < 1
            writeLog = true;
        end
        try
            if ~isempty(state.embeddedPreviewTimer) && isvalid(state.embeddedPreviewTimer)
                if strcmp(state.embeddedPreviewTimer.Running, 'on')
                    stop(state.embeddedPreviewTimer);
                end
            end
            if writeLog
                logMessage('In-app SDK Preview stopped.');
            end
        catch err
            if writeLog
                showError(err);
            end
        end
    end

    function updateEmbeddedSdkPreview(~, ~)
        try
            if isempty(state.ctx)
                stopEmbeddedPreview(false);
                return;
            end
            slm_capture_sdk_preview(state.ctx, state.embeddedPreviewFile);
            previewImage = imread(state.embeddedPreviewFile);
            showPreviewImage(liveAxes, previewImage, 'Live SDK Preview');
        catch err
            stopEmbeddedPreview(false);
            logMessage(sprintf('Embedded SDK Preview stopped: %s', err.message));
        end
    end

    function onRefreshPatterns(~, ~)
        try
            patternCount = refreshPatternList();
            logMessage(sprintf('Pattern list refreshed: %d pattern(s).', patternCount));
        catch err
            showError(err);
        end
    end

    function patternCount = refreshPatternList(preferredName)
        if nargin < 1 || isempty(preferredName)
            preferredName = selectedPatternName(false);
        end

        names = cellstr(slm_list_patterns(state.cfg));
        patternCount = numel(names);
        if isempty(names)
            patternListBox.Items = {noPatternListItem};
            patternListBox.Value = noPatternListItem;
            syncSavedPatternControls();
            return;
        end

        patternListBox.Items = names;
        if ~isempty(preferredName) && any(strcmp(names, preferredName))
            patternListBox.Value = preferredName;
        else
            patternListBox.Value = names{1};
        end
        syncSavedPatternControls();
    end

    function onShowSelectedPattern(~, ~)
        try
            requireConnection();
            patternName = selectedPatternName(true);
            state.currentPattern = slm_load_pattern(patternName, state.cfg);
            adjustedPattern = updatePreview(state.currentPattern, state.ctx);
            slm_show_pattern(state.ctx, adjustedPattern);
            updateCurrentOnSlm(adjustedPattern.name);
            logMessage(sprintf('Show saved pattern with global adjustments: %s.', patternName));
        catch err
            showError(err);
        end
    end

    function onPreviewSelectedPattern(~, ~)
        try
            patternName = selectedPatternName(true);
            state.currentPattern = slm_load_pattern(patternName, state.cfg);
            updatePreview(state.currentPattern, getGenerationContext());
            logMessage(sprintf('Preview saved pattern with global adjustments: %s.', patternName));
        catch err
            showError(err);
        end
    end

    function onDeleteSelectedPattern(~, ~)
        try
            patternName = selectedPatternName(true);
            choice = uiconfirm(fig, sprintf('Delete saved pattern "%s"?', patternName), ...
                'Delete Saved Pattern', ...
                'Options', {'Delete', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
            if ~strcmp(choice, 'Delete')
                return;
            end

            filePath = slm_pattern_path(patternName, state.cfg);
            if exist(filePath, 'file') ~= 2
                error('SLM:PatternFileMissing', 'Saved pattern file was not found: %s', filePath);
            end
            delete(filePath);
            patternCount = refreshPatternList();
            logMessage(sprintf('Deleted saved pattern: %s. %d pattern(s) remain.', ...
                patternName, patternCount));
        catch err
            showError(err);
        end
    end

    function onGeneratePreview(~, ~)
        try
            state.currentPattern = slm_generate_drill_beam_phase(getGenerationContext(), readDrillOptions());
            updatePreview(state.currentPattern, getGenerationContext());
            publishCurrentDrillOptions();
            logMessage(sprintf('Generated preview: %s.', state.currentPattern.name));
        catch err
            showError(err);
        end
    end

    function onGenerateShow(~, ~)
        try
            requireConnection();
            state.currentPattern = slm_generate_drill_beam_phase(state.ctx, readDrillOptions());
            adjustedPattern = updatePreview(state.currentPattern, state.ctx);
            slm_show_pattern(state.ctx, adjustedPattern);
            updateCurrentOnSlm(adjustedPattern.name);
            publishCurrentDrillOptions();
            logMessage(sprintf('Generated and showed with global adjustments: %s.', state.currentPattern.name));
        catch err
            showError(err);
        end
    end

    function onSaveCurrent(~, ~)
        try
            if isempty(state.currentPattern)
                error('SLM:NoCurrentPattern', 'Generate or load a pattern first.');
            end
            filePath = slm_save_pattern(state.currentPattern, state.currentPattern.name, state.cfg);
            refreshPatternList(state.currentPattern.name);
            publishCurrentDrillOptions();
            logMessage(sprintf('Saved current pattern: %s.', filePath));
        catch err
            showError(err);
        end
    end

    function patternName = selectedPatternName(requireSelection)
        if nargin < 1
            requireSelection = true;
        end

        patternName = '';
        selectedValue = patternListBox.Value;
        if iscell(selectedValue)
            if isempty(selectedValue)
                selectedValue = '';
            else
                selectedValue = selectedValue{1};
            end
        end

        if ~isempty(selectedValue) && ~strcmp(selectedValue, noPatternListItem)
            patternName = char(selectedValue);
        end

        if requireSelection && isempty(patternName)
            error('SLM:NoPatternSelected', 'Select a saved pattern first.');
        end
    end

    function syncSavedPatternControls()
        hasPattern = ~isempty(selectedPatternName(false));
        if hasPattern
            previewSelectedButton.Enable = 'on';
            showSelectedButton.Enable = 'on';
            deleteSelectedButton.Enable = 'on';
        else
            previewSelectedButton.Enable = 'off';
            showSelectedButton.Enable = 'off';
            deleteSelectedButton.Enable = 'off';
        end
    end

    function onGlobalAdjustmentSelectionChanged(~, ~)
        adjustmentName = selectedGlobalAdjustmentName(false);
        if ~isempty(adjustmentName)
            globalAdjustmentNameField.Value = adjustmentName;
        end
        syncSavedGlobalAdjustmentControls();
    end

    function onRefreshGlobalAdjustments(~, ~)
        try
            adjustmentCount = refreshGlobalAdjustmentList();
            logMessage(sprintf('Global adjustment list refreshed: %d preset(s).', adjustmentCount));
        catch err
            showError(err);
        end
    end

    function adjustmentCount = refreshGlobalAdjustmentList(preferredName)
        if nargin < 1 || isempty(preferredName)
            preferredName = selectedGlobalAdjustmentName(false);
        end

        names = cellstr(slm_list_global_adjustments(state.cfg));
        adjustmentCount = numel(names);
        if isempty(names)
            globalAdjustmentListBox.Items = {noGlobalAdjustmentListItem};
            globalAdjustmentListBox.Value = noGlobalAdjustmentListItem;
            syncSavedGlobalAdjustmentControls();
            return;
        end

        globalAdjustmentListBox.Items = names;
        if ~isempty(preferredName) && any(strcmp(names, preferredName))
            globalAdjustmentListBox.Value = preferredName;
        else
            globalAdjustmentListBox.Value = names{1};
        end
        globalAdjustmentNameField.Value = char(globalAdjustmentListBox.Value);
        syncSavedGlobalAdjustmentControls();
    end

    function onSaveGlobalAdjustment(~, ~)
        try
            adjustmentName = strtrim(globalAdjustmentNameField.Value);
            if isempty(adjustmentName)
                error('SLM:MissingGlobalAdjustmentName', 'Enter a global adjustment name first.');
            end

            savedName = slm_sanitize_pattern_name(adjustmentName);
            targetFilePath = slm_global_adjustment_path(savedName, state.cfg);
            if exist(targetFilePath, 'file')
                confirmMessage = sprintf('Overwrite saved global adjustment "%s"?', savedName);
            else
                confirmMessage = sprintf('Save global adjustment "%s"?', savedName);
            end
            choice = uiconfirm(fig, confirmMessage, ...
                'Save Global Adjustment', ...
                'Options', {'Save', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2);
            if ~strcmp(choice, 'Save')
                return;
            end

            filePath = slm_save_global_adjustment(readGlobalAdjustmentOptions(), adjustmentName, state.cfg);
            globalAdjustmentNameField.Value = savedName;
            refreshGlobalAdjustmentList(savedName);
            logMessage(sprintf('Saved global adjustment preset: %s.', filePath));
        catch err
            showError(err);
        end
    end

    function onApplySelectedGlobalAdjustment(~, ~)
        try
            adjustmentName = selectedGlobalAdjustmentName(true);
            globalAdjustment = slm_load_global_adjustment(adjustmentName, state.cfg);
            applyGlobalAdjustmentOptions(globalAdjustment.options);
            globalAdjustmentNameField.Value = adjustmentName;
            onGlobalAdjustmentChanged([], []);
            logMessage(sprintf('Applied global adjustment preset: %s.', adjustmentName));
        catch err
            showError(err);
        end
    end

    function onDeleteSelectedGlobalAdjustment(~, ~)
        try
            adjustmentName = selectedGlobalAdjustmentName(true);
            choice = uiconfirm(fig, sprintf('Delete saved global adjustment "%s"?', adjustmentName), ...
                'Delete Global Adjustment', ...
                'Options', {'Delete', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
            if ~strcmp(choice, 'Delete')
                return;
            end

            filePath = slm_global_adjustment_path(adjustmentName, state.cfg);
            if exist(filePath, 'file') ~= 2
                error('SLM:GlobalAdjustmentFileMissing', ...
                    'Saved global adjustment file was not found: %s', filePath);
            end
            delete(filePath);
            adjustmentCount = refreshGlobalAdjustmentList();
            logMessage(sprintf('Deleted global adjustment preset: %s. %d preset(s) remain.', ...
                adjustmentName, adjustmentCount));
        catch err
            showError(err);
        end
    end

    function onPreviewModeChanged(~, ~)
        try
            if ~isempty(state.currentPattern) && isfield(state.currentPattern, 'phaseData')
                updatePreview(state.currentPattern, getGenerationContext());
            end
            logMessage(sprintf('Preview mode: %s.', char(string(previewModeDropDown.Value))));
        catch err
            showError(err);
        end
    end

    function adjustmentName = selectedGlobalAdjustmentName(requireSelection)
        if nargin < 1
            requireSelection = true;
        end

        adjustmentName = '';
        selectedValue = globalAdjustmentListBox.Value;
        if iscell(selectedValue)
            if isempty(selectedValue)
                selectedValue = '';
            else
                selectedValue = selectedValue{1};
            end
        end

        if ~isempty(selectedValue) && ~strcmp(selectedValue, noGlobalAdjustmentListItem)
            adjustmentName = char(selectedValue);
        end

        if requireSelection && isempty(adjustmentName)
            error('SLM:NoGlobalAdjustmentSelected', 'Select a saved global adjustment first.');
        end
    end

    function syncSavedGlobalAdjustmentControls()
        hasAdjustment = ~isempty(selectedGlobalAdjustmentName(false));
        if hasAdjustment
            applyGlobalAdjustmentButton.Enable = 'on';
            deleteGlobalAdjustmentButton.Enable = 'on';
        else
            applyGlobalAdjustmentButton.Enable = 'off';
            deleteGlobalAdjustmentButton.Enable = 'off';
        end
    end

    function applyGlobalAdjustmentOptions(options)
        defaults = defaultGlobalAdjustmentOptions();

        setGlobalAdjustmentValue(globalLensField, globalLensSlider, ...
            numericGlobalAdjustmentOption(options, 'lensFocalLengthMm', defaults.lensFocalLengthMm));
        setGlobalAdjustmentValue(globalXShiftField, globalXShiftSlider, ...
            numericGlobalAdjustmentOption(options, 'xShiftTwoPi', defaults.xShiftTwoPi));
        setGlobalAdjustmentValue(globalYShiftField, globalYShiftSlider, ...
            numericGlobalAdjustmentOption(options, 'yShiftTwoPi', defaults.yShiftTwoPi));

        apertureRadiusPx = numericGlobalAdjustmentOption(options, ...
            'apertureRadiusPx', defaults.apertureRadiusPx);
        if ~isfinite(apertureRadiusPx) || apertureRadiusPx <= 0
            apertureRadiusPx = 0;
        end
        setGlobalAdjustmentValue(globalApertureRadiusField, globalApertureRadiusSlider, apertureRadiusPx);
        setGlobalAdjustmentValue(globalApertureCenterXField, globalApertureCenterXSlider, ...
            numericGlobalAdjustmentOption(options, 'apertureCenterXpx', defaults.apertureCenterXpx));
        setGlobalAdjustmentValue(globalApertureCenterYField, globalApertureCenterYSlider, ...
            numericGlobalAdjustmentOption(options, 'apertureCenterYpx', defaults.apertureCenterYpx));

        clearActiveGlobalControl();
    end

    function options = defaultGlobalAdjustmentOptions()
        options = struct();
        options.lensFocalLengthMm = 0;
        options.xShiftTwoPi = 0;
        options.yShiftTwoPi = 0;
        options.apertureRadiusPx = Inf;
        options.apertureCenterXpx = 0;
        options.apertureCenterYpx = 0;
    end

    function value = numericGlobalAdjustmentOption(options, fieldName, defaultValue)
        value = defaultValue;
        if isstruct(options) && isfield(options, fieldName) && ...
                isnumeric(options.(fieldName)) && isscalar(options.(fieldName)) && ...
                ~isnan(options.(fieldName))
            value = double(options.(fieldName));
        end
    end

    function setGlobalAdjustmentValue(field, slider, value)
        field.Value = value;
        slider.Value = clampSliderValue(value, slider.Limits);
    end

    function clearActiveGlobalControl()
        state.activeGlobalControlIndex = [];
        for index = 1:numel(globalControlRows)
            globalControlRows(index).label.FontWeight = 'normal';
        end
    end

    function onGlobalAdjustmentChanged(~, ~)
        try
            publishCurrentDrillOptions();
            if isempty(state.currentPattern)
                return;
            end
            if isempty(state.ctx)
                updatePreview(state.currentPattern, getGenerationContext());
                logMessage('Global adjustment preview updated.');
                return;
            end

            adjustedPattern = updatePreview(state.currentPattern, state.ctx);
            slm_show_pattern(state.ctx, adjustedPattern);
            updateCurrentOnSlm(adjustedPattern.name);
            publishCurrentDrillOptions();
            logMessage(sprintf('Global adjustment updated on SLM: %s.', adjustedPattern.name));
        catch err
            showError(err);
        end
    end

    function onResetGlobalAdjustments(~, ~)
        try
            choice = uiconfirm(fig, 'Reset all global adjustments to defaults?', ...
                'Reset Global Adjustments', ...
                'Options', {'Reset', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
            if ~strcmp(choice, 'Reset')
                return;
            end

            applyGlobalAdjustmentOptions(defaultGlobalAdjustmentOptions());
            onGlobalAdjustmentChanged([], []);
            logMessage('Global adjustments reset to defaults.');
        catch err
            showError(err);
        end
    end

    function ctx = getGenerationContext()
        if isempty(state.ctx)
            ctx = struct();
            ctx.widthPx = state.cfg.expectedWidthPx;
            ctx.heightPx = state.cfg.expectedHeightPx;
            ctx.config = state.cfg;
        else
            ctx = state.ctx;
        end
    end

    function options = readDrillOptions()
        options = slm_default_drill_beam_options();
        options.name = nameField.Value;
        options.axiconMode = char(string(axiconModeDropDown.Value));
        options.axiconConeAngleDeg = axiconConeAngleField.Value;
        options.axiconRadialPeriodMm = axiconRadialPeriodMmField.Value;
        options.axiconRadialPeriodPx = axiconRadialPeriodPxField.Value;
        options.axiconRadialCycles = axiconRadialCyclesField.Value;
        options.axiconIndex = axiconIndexField.Value;
        options.axiconPhysicalBaseAngleDeg = axiconPhysicalBaseAngleField.Value;
        options.axiconAngleDeg = axiconConeAngleField.Value;
        options.vortexCharge = vortexField.Value;
        options.helicalGamma = helicalGammaField.Value;
        options.helicalOrder = helicalOrderField.Value;
        options.helicalOffsetDeg = helicalOffsetField.Value;
        options.omegaInner = omegaInnerField.Value;
        options.omegaOuter = omegaOuterField.Value;
        options.lensFocalLengthMm = Inf;
        options.carrierPeriodPx = Inf;
        options.apertureRadiusPx = Inf;
    end

    function options = readGlobalAdjustmentOptions()
        options = struct();
        options.lensFocalLengthMm = globalLensField.Value;
        options.xShiftTwoPi = globalXShiftField.Value;
        options.yShiftTwoPi = globalYShiftField.Value;
        if globalApertureRadiusField.Value <= 0
            options.apertureRadiusPx = Inf;
        else
            options.apertureRadiusPx = globalApertureRadiusField.Value;
        end
        options.apertureCenterXpx = globalApertureCenterXField.Value;
        options.apertureCenterYpx = globalApertureCenterYField.Value;
    end

    function publishCurrentDrillOptions()
        try
            snapshot = struct();
            snapshot.source = "laser-writing-embedded-slm";
            snapshot.updatedAt = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
            snapshot.isOpen = isvalid(fig);
            snapshot.isConnected = ~isempty(state.ctx);
            snapshot.currentOnSlm = string(state.currentOnSlm);
            snapshot.options = readDrillOptions();
            snapshot.globalAdjustments = readGlobalAdjustmentOptions();
            if ~isempty(state.currentPattern) && isfield(state.currentPattern, 'name')
                snapshot.currentPatternName = string(state.currentPattern.name);
            else
                snapshot.currentPatternName = "";
            end
            if ~isempty(state.currentAdjustedPattern) && isfield(state.currentAdjustedPattern, 'name')
                snapshot.currentAdjustedPatternName = string(state.currentAdjustedPattern.name);
            else
                snapshot.currentAdjustedPatternName = "";
            end
            setappdata(0, slmSnapshotAppDataKey, snapshot);
        catch
        end
    end

    function adjustedPattern = updatePreview(pattern, ctx)
        if nargin < 2 || isempty(ctx)
            ctx = getGenerationContext();
        end
        adjustedPattern = [];
        if isempty(pattern) || ~isfield(pattern, 'phaseData')
            clearPatternAxes(basePreviewAxes, 'No base pattern loaded');
            clearPatternAxes(adjustedPreviewAxes, 'No adjusted pattern loaded');
            state.currentAdjustedPattern = [];
            return;
        end

        adjustedPattern = applyGlobalAdjustments(pattern, ctx);
        state.currentAdjustedPattern = adjustedPattern;

        baseName = patternDisplayName(pattern);
        showPatternPreview(basePreviewAxes, pattern, ['Base: ', baseName]);
        showPatternPreview(adjustedPreviewAxes, adjustedPattern, ['Global: ', adjustedPattern.name]);
    end

    function clearPatternAxes(targetAxes, labelText)
        cla(targetAxes);
        axis(targetAxes, 'image');
        targetAxes.XTick = [];
        targetAxes.YTick = [];
        title(targetAxes, labelText, 'Interpreter', 'none');
    end

    function showPatternPreview(targetAxes, pattern, labelText)
        [previewData, previewLabel] = patternPreviewData(pattern, labelText);
        imagesc(targetAxes, previewData);
        axis(targetAxes, 'image');
        targetAxes.XTick = [];
        targetAxes.YTick = [];
        colormap(targetAxes, gray(256));
        title(targetAxes, previewLabel, 'Interpreter', 'none');
    end

    function [previewData, previewLabel] = patternPreviewData(pattern, labelText)
        previewMode = char(string(previewModeDropDown.Value));
        switch previewMode
            case 'Raw helical phase'
                previewData = drillHelicalPreview(pattern);
                previewLabel = [labelText, ' | raw helical'];
            otherwise
                phaseUnit = patternPhaseUnit(pattern, []);
                previewData = mod(double(pattern.phaseData), double(phaseUnit));
                previewLabel = [labelText, ' | wrapped SLM'];
        end
    end

    function helicalPreview = drillHelicalPreview(pattern)
        if ~isstruct(pattern) || ~isfield(pattern, 'phaseData')
            error('SLM:InvalidPattern', 'pattern must contain phaseData.');
        end

        options = slm_default_drill_beam_options();
        if isfield(pattern, 'options') && isstruct(pattern.options)
            options = slm_apply_defaults(pattern.options, options);
        end

        [heightPx, widthPx] = size(pattern.phaseData);
        xPx = (1:double(widthPx)) - double(widthPx) / 2 - double(options.centerXpx);
        yPx = (1:double(heightPx)) - double(heightPx) / 2 + double(options.centerYpx);
        [xPxGrid, yPxGrid] = meshgrid(single(xPx), single(yPx));

        [theta, ~] = cart2pol(double(xPxGrid), double(yPxGrid));
        radiusPx = hypot(double(xPxGrid), double(yPxGrid));
        rho = radiusPx ./ (min(double(widthPx), double(heightPx)) / 2);
        radialChirp = 2 * pi * ( ...
            double(options.omegaInner) .* rho + ...
            0.5 * (double(options.omegaOuter) - double(options.omegaInner)) .* rho .^ 2);
        helicalPreview = double(options.helicalGamma) .* cos( ...
            double(options.helicalOrder) .* theta - ...
            radialChirp + deg2rad(double(options.helicalOffsetDeg)));
    end

    function adjustedPattern = applyGlobalAdjustments(pattern, ctx)
        globalOptions = readGlobalAdjustmentOptions();
        phaseUnit = patternPhaseUnit(pattern, ctx);
        phase = single(pattern.phaseData);
        [heightPx, widthPx] = size(phase);
        [xPxGrid, yPxGrid] = centeredPixelGrid(widthPx, heightPx);

        if isfinite(globalOptions.lensFocalLengthMm) && globalOptions.lensFocalLengthMm ~= 0
            cfg = globalAdjustmentConfig(pattern, ctx);
            pixelPitchMm = double(cfg.pixelPitchUm) * 1e-3;
            wavelengthMm = double(cfg.wavelengthNm) * 1e-6;
            k = 2 * pi / wavelengthMm;
            radiusMm = hypot(double(xPxGrid), double(yPxGrid)) * pixelPitchMm;
            phase = phase + single(k .* (radiusMm .^ 2) ./ ...
                (2 * double(globalOptions.lensFocalLengthMm)));
        end

        if isfinite(globalOptions.xShiftTwoPi) && globalOptions.xShiftTwoPi ~= 0
            phase = phase + single(2 * pi * double(globalOptions.xShiftTwoPi) .* ...
                double(xPxGrid) ./ double(widthPx));
        end

        if isfinite(globalOptions.yShiftTwoPi) && globalOptions.yShiftTwoPi ~= 0
            phase = phase + single(2 * pi * double(globalOptions.yShiftTwoPi) .* ...
                double(yPxGrid) ./ double(heightPx));
        end

        if isfinite(globalOptions.apertureRadiusPx)
            apertureRadiusPx = double(globalOptions.apertureRadiusPx);
            apertureMask = hypot( ...
                double(xPxGrid) - double(globalOptions.apertureCenterXpx), ...
                double(yPxGrid) - double(globalOptions.apertureCenterYpx)) <= apertureRadiusPx;
            phase(~apertureMask) = 0;
        end

        baseName = patternDisplayName(pattern);
        adjustedPattern = pattern;
        adjustedPattern.name = [baseName, ' + global'];
        adjustedPattern.phaseData = phase;
        adjustedPattern.phaseUnit = phaseUnit;
        adjustedPattern.basePatternName = baseName;
        adjustedPattern.globalAdjustments = globalOptions;
    end

    function [xPxGrid, yPxGrid] = centeredPixelGrid(widthPx, heightPx)
        xPx = (1:double(widthPx)) - double(widthPx) / 2;
        yPx = (1:double(heightPx)) - double(heightPx) / 2;
        [xPxGrid, yPxGrid] = meshgrid(single(xPx), single(yPx));
    end

    function cfg = globalAdjustmentConfig(pattern, ctx)
        cfg = state.cfg;
        if nargin >= 2 && isstruct(ctx) && isfield(ctx, 'config')
            cfg = ctx.config;
        end
        if isstruct(pattern) && isfield(pattern, 'options') && isstruct(pattern.options)
            if isfield(pattern.options, 'wavelengthNm') && ~isempty(pattern.options.wavelengthNm)
                cfg.wavelengthNm = pattern.options.wavelengthNm;
            end
            if isfield(pattern.options, 'pixelPitchUm') && ~isempty(pattern.options.pixelPitchUm)
                cfg.pixelPitchUm = pattern.options.pixelPitchUm;
            end
        end
        if ~isfield(cfg, 'wavelengthNm') || isempty(cfg.wavelengthNm)
            cfg.wavelengthNm = state.cfg.wavelengthNm;
        end
        if ~isfield(cfg, 'pixelPitchUm') || isempty(cfg.pixelPitchUm)
            cfg.pixelPitchUm = state.cfg.pixelPitchUm;
        end
    end

    function phaseUnit = patternPhaseUnit(pattern, ctx)
        phaseUnit = 2*pi;
        if nargin >= 1 && isstruct(pattern) && isfield(pattern, 'phaseUnit') && ~isempty(pattern.phaseUnit)
            phaseUnit = pattern.phaseUnit;
        elseif nargin >= 2 && isstruct(ctx) && isfield(ctx, 'config') && ...
                isfield(ctx.config, 'phaseUnit') && ~isempty(ctx.config.phaseUnit)
            phaseUnit = ctx.config.phaseUnit;
        end
    end

    function name = patternDisplayName(pattern)
        name = 'pattern';
        if isstruct(pattern) && isfield(pattern, 'name') && ~isempty(pattern.name)
            name = char(pattern.name);
        end
    end

    function showPreviewImage(targetAxes, previewImage, labelText)
        if ismatrix(previewImage)
            imagesc(targetAxes, previewImage);
            colormap(targetAxes, gray(256));
        else
            image(targetAxes, previewImage);
        end
        axis(targetAxes, 'image');
        targetAxes.XTick = [];
        targetAxes.YTick = [];
        title(targetAxes, labelText, 'Interpreter', 'none');
    end

    function updateConnectionStatus()
        if isempty(state.ctx)
            statusLabel.Text = 'Status: disconnected';
            statusLabel.FontColor = [0.45 0.05 0.05];
            connectButton.Text = 'Connect SLM';
        else
            statusLabel.Text = sprintf('Status: connected (%d x %d)', ...
                state.ctx.widthPx, state.ctx.heightPx);
            statusLabel.FontColor = [0.05 0.35 0.12];
            connectButton.Text = 'Disconnect SLM';
        end
    end

    function updateCurrentOnSlm(name)
        if nargin < 1 || isempty(name)
            name = 'unknown';
        end
        state.currentOnSlm = char(name);
        currentOnSlmLabel.Text = ['Current on SLM: ', state.currentOnSlm];
        publishCurrentDrillOptions();
    end

    function logMessage(message)
        timestamp = char(datetime('now', 'Format', 'HH:mm:ss'));
        currentValue = logArea.Value;
        if ischar(currentValue)
            currentValue = cellstr(currentValue);
        end
        logArea.Value = [currentValue(:); {sprintf('[%s] %s', timestamp, message)}];
        try
            scroll(logArea, 'bottom');
        catch
        end
        drawnow limitrate;
    end

    function showError(err)
        logMessage(sprintf('ERROR: %s', err.message));
        uialert(fig, err.message, 'SLM Control Error');
    end

    function onClose(~, ~)
        try
            rmappdata(0, slmSnapshotAppDataKey);
        catch
        end
        try
            stopEmbeddedPreview(false);
            if ~isempty(state.ctx)
                slm_close(state.ctx);
            end
        catch
        end
        try
            if ~isempty(state.embeddedPreviewTimer) && isvalid(state.embeddedPreviewTimer)
                delete(state.embeddedPreviewTimer);
            end
        catch
        end
        delete(fig);
    end
end

function localAddRepoPaths()
repoRoot = fileparts(mfilename('fullpath'));

addpath(repoRoot);
addpath(fullfile(repoRoot, 'config'));
addpath(fullfile(repoRoot, 'src'));
end
