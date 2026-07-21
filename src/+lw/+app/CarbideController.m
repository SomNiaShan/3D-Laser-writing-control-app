classdef CarbideController < handle
    %CARBIDECONTROLLER Own Carbide connection, polling, presets, and output state.

    properties (SetAccess = private)
        Model
        Ports
    end

    properties (Access = private)
        RequestInProgress (1, 1) logical = false
    end

    methods
        function obj = CarbideController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("CarbideController", ports, [ ...
                "appendUnit", "logMessage", "reportError", "runUiAction", "syncAll", ...
                "syncControlEnableStates", "syncStatusLabels"]);
        end

        function onConnectCarbide(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.connectCarbideImpl(), 'Failed to connect Carbide');
        end

        function connectCarbideImpl(obj)
            obj.requireCarbideEnabled();
            obj.stopCarbideStatusTimer();

            obj.Model.State.carbide.baseUrl = string(obj.Model.Services.carbide.baseUrl(obj.Model.Config));
            try
                basic = obj.runCarbideRequest(@() obj.Model.Services.carbide.getBasic(obj.Model.Config));
                validateCarbideBasicResponse(basic);
            catch ME
                obj.Model.State.carbide.connected = false;
                obj.Model.State.carbide.lastError = string(ME.message);
                rethrow(ME);
            end

            obj.Model.State.carbide.connected = true;
            obj.Model.State.carbide.lastBasic = basic;
            obj.Model.State.carbide.lastError = "";
            obj.Model.State.carbide.pollFailureCount = 0;
            obj.Ports.logMessage(sprintf('Carbide connected at %s.', char(obj.Model.State.carbide.baseUrl)));
            obj.Ports.logMessage(sprintf('Carbide Basic JSON: %s', compactJsonText(basic)));

            try
                obj.Model.State.carbide.presets = obj.runCarbideRequest( ...
                    @() obj.Model.Services.carbide.getPresets(obj.Model.Config));
                obj.updateCarbidePresetDropDown();
                obj.Ports.logMessage(sprintf('Carbide presets loaded: %d.', obj.carbidePresetCount()));
            catch ME
                obj.Model.State.carbide.presets = [];
                obj.Model.State.carbide.presetIndices = [];
                obj.Model.State.carbide.lastError = string(ME.message);
                obj.updateCarbidePresetDropDown();
                obj.Ports.logMessage(sprintf('Carbide preset list unavailable: %s', compactErrorMessage(ME)));
            end

            obj.resetCarbideCommandFieldsFromBasic();
            obj.startCarbideStatusTimer();
        end

        function onDisconnectCarbide(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.disconnectCarbideImpl(), 'Failed to disconnect Carbide');
        end

        function disconnectCarbideImpl(obj)
            obj.stopCarbideStatusTimer();
            defaultState = lw_default_state();
            obj.Model.State.carbide = defaultState.carbide;
            obj.updateCarbidePresetDropDown();
            obj.Ports.logMessage('Carbide disconnected.');
        end

        function onApplyCarbidePpDivider(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.applyCarbidePpDividerImpl(), 'Failed to set Carbide PP divider');
        end

        function applyCarbidePpDividerImpl(obj)
            obj.requireCarbideCanWrite();
            ppDivider = positiveInteger(obj.Model.Ui.CarbidePpDividerField.Value, 'Carbide PP divider');
            obj.assertCarbidePpDividerAllowed(ppDivider);
            obj.runCarbideRequest( ...
                @() obj.Model.Services.carbide.setPpDivider(obj.Model.Config, ppDivider));
            obj.refreshCarbideStatusOnce();
            obj.Ports.logMessage(sprintf('Carbide target PP divider set to %d.', ppDivider));
        end

        function onEnableCarbideOutput(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused || obj.Model.PausedManualMotionActive
                obj.Ports.reportError('Failed to open Carbide laser shutter', ...
                    MException('lw:CarbideBusy', 'The Carbide laser shutter can only be opened while the app is idle.'));
                return;
            end

            choice = string(obj.Model.Services.dialog.confirm(obj.Model.Figure, ...
                ['Open the Carbide laser shutter?' newline newline ...
                 'Confirm beam path, sample, enclosure/interlocks, and external shutter state before continuing.'], ...
                'Open Laser Shutter', ...
                'Options', {'Open Laser Shutter', 'Cancel'}, ...
                'DefaultOption', 'Cancel', ...
                'CancelOption', 'Cancel', ...
                'Icon', 'warning'));
            if choice ~= "Open Laser Shutter"
                return;
            end

            obj.Ports.runUiAction(@() obj.enableCarbideOutputImpl(), 'Failed to open Carbide laser shutter');
        end

        function enableCarbideOutputImpl(obj)
            obj.requireCarbideCanWrite();
            obj.runCarbideRequest( ...
                @() obj.Model.Services.carbide.enableOutput(obj.Model.Config));
            obj.refreshCarbideStatusOnce();
            obj.Ports.logMessage('Carbide laser shutter open command sent.');
        end

        function onCloseCarbideOutput(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.closeCarbideOutputImpl(), 'Failed to close Carbide laser shutter');
        end

        function closeCarbideOutputImpl(obj)
            obj.requireCarbideConnected();
            obj.runCarbideRequest( ...
                @() obj.Model.Services.carbide.closeOutput(obj.Model.Config));
            obj.refreshCarbideStatusOnce();
            obj.Ports.logMessage('Carbide laser shutter close command sent.');
        end

        function onStandbyCarbide(obj, ~, ~)
            if obj.Model.State.isBusy || obj.Model.State.isPaused || obj.Model.PausedManualMotionActive
                obj.Ports.reportError('Failed to put Carbide in standby', ...
                    MException('lw:CarbideBusy', 'Carbide standby can only be requested while the app is idle.'));
                return;
            end

            choice = string(obj.Model.Services.dialog.confirm(obj.Model.Figure, ...
                ['Put Carbide into standby and shut down the laser?' newline newline ...
                 'Restarting from standby may take several minutes.'], ...
                'Carbide Standby', ...
                'Options', {'Standby', 'Cancel'}, ...
                'DefaultOption', 'Cancel', ...
                'CancelOption', 'Cancel', ...
                'Icon', 'warning'));
            if choice ~= "Standby"
                return;
            end

            obj.Ports.runUiAction(@() obj.standbyCarbideImpl(), 'Failed to put Carbide in standby');
        end

        function standbyCarbideImpl(obj)
            obj.requireCarbideCanWrite();
            obj.runCarbideRequest( ...
                @() obj.Model.Services.carbide.standby(obj.Model.Config));
            obj.Ports.logMessage('Carbide standby command sent.');
            try
                obj.refreshCarbideStatusOnce();
            catch ME
                obj.Model.State.carbide.lastError = string(ME.message);
                obj.Ports.logMessage(sprintf('Carbide status refresh after standby unavailable: %s', compactErrorMessage(ME)));
            end
        end

        function onApplyCarbidePreset(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.applyCarbidePresetImpl(), 'Failed to apply Carbide preset');
        end

        function applyCarbidePresetImpl(obj)
            obj.requireCarbideCanWrite();
            presetIndex = obj.selectedCarbidePresetIndex();
            obj.runCarbideRequest( ...
                @() obj.Model.Services.carbide.selectPreset(obj.Model.Config, presetIndex));
            obj.runCarbideRequest( ...
                @() obj.Model.Services.carbide.applySelectedPreset(obj.Model.Config));
            obj.refreshCarbideStatusOnce();
            obj.resetCarbideCommandFieldsFromBasic();
            obj.Ports.logMessage(sprintf('Carbide preset %d applied.', presetIndex));
        end

        function requireCarbideEnabled(obj)
            if ~obj.isCarbideEnabled()
                error('Carbide control is disabled in hardware config.');
            end
        end

        function tf = isCarbideEnabled(obj)
            tf = isfield(obj.Model.Config, 'carbide') && ...
                (~isfield(obj.Model.Config.carbide, 'enabled') || logical(obj.Model.Config.carbide.enabled));
        end

        function requireCarbideConnected(obj)
            if ~obj.areCarbideConnected()
                error('Carbide is not connected.');
            end
        end

        function requireCarbideCanWrite(obj)
            obj.requireCarbideConnected();
            if obj.Model.State.isBusy || obj.Model.State.isPaused || obj.Model.PausedManualMotionActive
                error('Carbide parameters can only be changed while the app is idle.');
            end
        end

        function startCarbideStatusTimer(obj)
            if ~obj.areCarbideConnected()
                return;
            end

            obj.stopCarbideStatusTimer();
            pollPeriod = obj.carbidePollPeriodSeconds();
            if pollPeriod <= 0
                return;
            end

            obj.Model.State.carbide.statusTimer = obj.Model.Services.timer.create( ...
                'Name', 'LaserWritingCarbideStatus', ...
                'ExecutionMode', 'fixedSpacing', ...
                'BusyMode', 'drop', ...
                'Period', pollPeriod, ...
                'TimerFcn', @obj.onCarbideStatusTimer);
            start(obj.Model.State.carbide.statusTimer);
        end

        function stopCarbideStatusTimer(obj)
            try
                if isfield(obj.Model.State, 'carbide') && isstruct(obj.Model.State.carbide) && ...
                        isfield(obj.Model.State.carbide, 'statusTimer') && ~isempty(obj.Model.State.carbide.statusTimer) && ...
                        isvalid(obj.Model.State.carbide.statusTimer)
                    stop(obj.Model.State.carbide.statusTimer);
                    delete(obj.Model.State.carbide.statusTimer);
                end
            catch
            end
            if isfield(obj.Model.State, 'carbide') && isstruct(obj.Model.State.carbide)
                obj.Model.State.carbide.statusTimer = [];
            end
        end

        function onCarbideStatusTimer(obj, ~, ~)
            try
                if ~isvalid(obj.Model.Figure)
                    obj.stopCarbideStatusTimer();
                    return;
                end
            catch
                obj.stopCarbideStatusTimer();
                return;
            end

            if ~obj.areCarbideConnected()
                obj.stopCarbideStatusTimer();
                return;
            end

            if obj.RequestInProgress
                return;
            end

            try
                obj.refreshCarbideStatusOnce();
            catch ME
                if strcmp(ME.identifier, 'lw:CarbideRequestBusy')
                    return;
                end
                obj.Model.State.carbide.pollFailureCount = obj.Model.State.carbide.pollFailureCount + 1;
                obj.Model.State.carbide.lastError = string(ME.message);
                if obj.Model.State.carbide.pollFailureCount == 1
                    obj.Ports.logMessage(sprintf('Carbide status poll failed: %s', compactErrorMessage(ME)));
                end
                if obj.Model.State.carbide.pollFailureCount >= 3
                    obj.Model.State.carbide.connected = false;
                    obj.stopCarbideStatusTimer();
                    obj.Ports.logMessage('Carbide status polling stopped after repeated failures.');
                end
            end

            obj.Ports.syncStatusLabels();
            obj.syncCarbideUi();
            obj.Ports.syncControlEnableStates();
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function refreshCarbideStatusOnce(obj)
            basic = obj.runCarbideRequest(@() obj.Model.Services.carbide.getBasic(obj.Model.Config));
            validateCarbideBasicResponse(basic);
            obj.Model.State.carbide.connected = true;
            obj.Model.State.carbide.lastBasic = basic;
            obj.Model.State.carbide.lastError = "";
            obj.Model.State.carbide.pollFailureCount = 0;
        end

        function pollPeriod = carbidePollPeriodSeconds(obj)
            pollPeriod = 0.5;
            if isfield(obj.Model.Config, 'carbide') && isfield(obj.Model.Config.carbide, 'pollPeriodSeconds')
                pollPeriod = double(obj.Model.Config.carbide.pollPeriodSeconds);
            end
        end

        function assertCarbidePpDividerAllowed(obj, ppDivider)
            rangeValues = obj.carbideRangeFromBasic(["AvailablePpDividerRange", "PpDividerRange", "TargetPpDividerRange"]);
            knownValues = obj.carbidePresetNumericValues(["PpDivider", "TargetPpDivider", "TargetPPDivider"]);
            obj.assertCarbideKnownOrInRange(ppDivider, rangeValues, knownValues, ...
                'Carbide PP divider', 1e-9);
        end

        function assertCarbideKnownOrInRange(obj, value, rangeValues, knownValues, labelText, tolerance)
            value = double(value);
            rangeValues = rangeValues(isfinite(rangeValues));
            knownValues = knownValues(isfinite(knownValues));

            if numel(rangeValues) >= 2
                lowerLimit = min(rangeValues);
                upperLimit = max(rangeValues);
                if value >= lowerLimit - tolerance && value <= upperLimit + tolerance
                    return;
                end
                error('%s %.6g is outside the allowed range %.6g to %.6g.', ...
                    labelText, value, lowerLimit, upperLimit);
            end

            if ~isempty(knownValues)
                if any(abs(value - knownValues) <= tolerance)
                    return;
                end
                obj.Ports.logMessage(sprintf(['%s %.6g is not one of the downloaded preset values (%s); ', ...
                    'submitting because Carbide did not report an API range.'], ...
                    labelText, value, char(join(string(unique(knownValues(:).')), ', '))));
                return;
            end

            obj.Ports.logMessage(sprintf('%s limits were not reported by Carbide; submitting value to Carbide for validation.', labelText));
        end

        function updateCarbidePresetDropDown(obj)
            [items, indices] = obj.carbidePresetItems();
            obj.Model.State.carbide.presetIndices = indices;
            obj.Model.Ui.CarbidePresetDropDown.Items = items;
            if isempty(items)
                obj.Model.Ui.CarbidePresetDropDown.Items = {'(not loaded)'};
                obj.Model.Ui.CarbidePresetDropDown.Value = '(not loaded)';
                return;
            end

            selectedIndex = carbideNumericField(obj.Model.State.carbide.lastBasic, ...
                ["SelectedPresetIndex", "ActualSelectedPresetIndex", "LastExecutedPresetIndex"]);
            selectedItemIndex = find(indices == selectedIndex, 1, 'first');
            if isempty(selectedItemIndex)
                selectedItemIndex = 1;
            end
            obj.Model.Ui.CarbidePresetDropDown.Value = items{selectedItemIndex};
        end

        function [items, indices] = carbidePresetItems(obj)
            presets = obj.carbidePresetArray();
            if isempty(presets)
                items = {'(not loaded)'};
                indices = NaN;
                return;
            end

            presetCount = numel(presets);
            items = cell(1, presetCount);
            indices = zeros(1, presetCount);
            for presetIndex = 1:presetCount
                preset = presets(presetIndex);
                indexValue = carbideNumericField(preset, ["Index", "PresetIndex"]);
                if ~isfinite(indexValue)
                    indexValue = presetIndex - 1;
                end
                nameValue = carbideTextField(preset, ["Name", "PresetName", "Label"], sprintf('Preset %d', indexValue));
                indices(presetIndex) = indexValue;
                items{presetIndex} = sprintf('%d: %s', indexValue, char(nameValue));
            end
        end

        function presetCount = carbidePresetCount(obj)
            presetCount = numel(obj.carbidePresetArray());
        end

        function presets = carbidePresetArray(obj)
            presets = struct([]);
            if ~isfield(obj.Model.State, 'carbide') || ~isstruct(obj.Model.State.carbide) || isempty(obj.Model.State.carbide.presets)
                return;
            end

            rawPresets = obj.Model.State.carbide.presets;
            if isstruct(rawPresets) && isscalar(rawPresets)
                nestedPresets = carbideField(rawPresets, ["Presets", "PresetList", "Items", "Data", "Value"], []);
                if isstruct(nestedPresets)
                    rawPresets = nestedPresets;
                end
            end

            if isstruct(rawPresets) && isscalar(rawPresets)
                rawFields = fieldnames(rawPresets);
                for rawFieldIndex = 1:numel(rawFields)
                    fieldValue = rawPresets.(rawFields{rawFieldIndex});
                    if isstruct(fieldValue) && numel(fieldValue) > 1
                        rawPresets = fieldValue;
                        break;
                    end
                end
            end

            if isstruct(rawPresets)
                presets = rawPresets(:);
            end
        end

        function presetIndex = selectedCarbidePresetIndex(obj)
            if isempty(obj.Model.State.carbide.presetIndices) || all(~isfinite(obj.Model.State.carbide.presetIndices))
                error('No Carbide presets have been loaded.');
            end
            selectedItem = string(obj.Model.Ui.CarbidePresetDropDown.Value);
            items = string(obj.Model.Ui.CarbidePresetDropDown.Items);
            itemIndex = find(items == selectedItem, 1, 'first');
            if isempty(itemIndex) || itemIndex > numel(obj.Model.State.carbide.presetIndices)
                error('Select a valid Carbide preset.');
            end
            presetIndex = obj.Model.State.carbide.presetIndices(itemIndex);
            if ~isfinite(presetIndex)
                error('Select a valid Carbide preset.');
            end
        end

        function resetCarbideCommandFieldsFromBasic(obj)
            basic = obj.Model.State.carbide.lastBasic;
            ppDivider = carbideNumericField(basic, ["TargetPpDivider", "ActualPpDivider"]);
            if isfinite(ppDivider)
                obj.Model.Ui.CarbidePpDividerField.Value = ppDivider;
            end
        end

        function syncCarbideUi(obj)
            connected = obj.areCarbideConnected();
            lastError = "";
            if isfield(obj.Model.State, 'carbide') && isfield(obj.Model.State.carbide, 'lastError')
                lastError = string(obj.Model.State.carbide.lastError);
            end

            if ~connected
                obj.Model.Ui.CarbideStatusLabel.Text = 'Disconnected';
                obj.Model.Ui.CarbideActualPowerLabel.Text = '-';
                obj.Model.Ui.CarbideActualFrequencyLabel.Text = '-';
                obj.Model.Ui.CarbideRepetitionPeriodLabel.Text = '-';
                obj.Model.Ui.CarbideActualPpLabel.Text = '-';
                obj.Model.Ui.CarbideActualPulseLabel.Text = '-';
                obj.Model.Ui.CarbideOutputEnabledLabel.Text = '-';
                obj.Model.Ui.CarbideShutterStateLabel.Text = '-';
                obj.Model.Ui.CarbidePulseEnergyLabel.Text = '-';
                obj.Model.Ui.CarbideSelectedPresetLabel.Text = '-';
                obj.Model.Ui.CarbideLastErrorLabel.Text = char(lastError);
                return;
            end

            basic = obj.Model.State.carbide.lastBasic;
            obj.Model.Ui.CarbideStatusLabel.Text = sprintf('Connected: %s | State: %s', ...
                char(obj.Model.State.carbide.baseUrl), char(carbideOperatingStateText(basic)));
            obj.Model.Ui.CarbideActualPowerLabel.Text = formatCarbideNumericField(basic, ["ActualOutputPower", "OutputPower", "ActualPower"]);
            obj.Model.Ui.CarbideActualFrequencyLabel.Text = formatCarbideNumericField(basic, ["ActualOutputFrequency", "ActualFrequency", "OutputFrequency"]);
            obj.Model.Ui.CarbideRepetitionPeriodLabel.Text = formatCarbideRepetitionPeriodField(basic);
            obj.Model.Ui.CarbideActualPpLabel.Text = formatCarbideNumericField(basic, ["ActualPpDivider", "PpDivider"]);
            obj.Model.Ui.CarbideActualPulseLabel.Text = formatCarbideNumericField(basic, ["ActualPulseDuration", "PulseDuration"]);
            obj.Model.Ui.CarbideOutputEnabledLabel.Text = formatCarbideOutputEnabled(basic);
            obj.Model.Ui.CarbideShutterStateLabel.Text = char(carbideShutterStateText(basic));
            obj.Model.Ui.CarbidePulseEnergyLabel.Text = formatCarbidePulseEnergyField(basic);
            obj.Model.Ui.CarbideSelectedPresetLabel.Text = obj.formatCarbideSelectedPreset();
            obj.Model.Ui.CarbideLastErrorLabel.Text = char(lastError);
        end

        function [stateText, stateColor, tooltipText] = carbideStateStatus(obj, carbideConnected)
            stateText = "-";
            stateColor = lampColor(false);
            tooltipText = obj.carbideStatusTooltip();
            if ~carbideConnected
                return;
            end

            stateText = "Unknown";
            stateColor = [0.5, 0.5, 0.5];
            tooltipText = 'Carbide state unknown.';
            if isfield(obj.Model.State.carbide, 'lastBasic') && ~isempty(obj.Model.State.carbide.lastBasic)
                basic = obj.Model.State.carbide.lastBasic;
                stateText = carbideOperatingStateText(basic);
                stateColor = carbideOperatingStateColor(stateText, basic);
                tooltipText = carbideOperatingStateTooltip(stateText, basic);
            end
        end

        function [shutterText, shutterColor, tooltipText] = carbideShutterStatus(obj, carbideConnected)
            shutterText = "-";
            shutterColor = [0.5, 0.5, 0.5];
            tooltipText = obj.carbideStatusTooltip();
            if ~carbideConnected
                return;
            end

            shutterText = "Unknown";
            tooltipText = 'Carbide physical shutter state unknown.';
            if isfield(obj.Model.State.carbide, 'lastBasic') && ~isempty(obj.Model.State.carbide.lastBasic)
                basic = obj.Model.State.carbide.lastBasic;
                shutterText = carbideShutterStateText(basic);
                shutterColor = carbideShutterStateColor(shutterText);
                tooltipText = carbideShutterStateTooltip(shutterText, basic);
            end
        end

        function textValue = formatCarbideSelectedPreset(obj)
            selectedIndex = carbideNumericField(obj.Model.State.carbide.lastBasic, ...
                ["SelectedPresetIndex", "ActualSelectedPresetIndex", "LastExecutedPresetIndex"]);
            if ~isfinite(selectedIndex)
                textValue = '-';
                return;
            end

            if ~isempty(obj.Model.State.carbide.presetIndices)
                matchIndex = find(obj.Model.State.carbide.presetIndices == selectedIndex, 1, 'first');
                if ~isempty(matchIndex)
                    items = obj.Model.Ui.CarbidePresetDropDown.Items;
                    textValue = items{matchIndex};
                    return;
                end
            end

            textValue = sprintf('%d', round(selectedIndex));
        end

        function rangeValues = carbideRangeFromBasic(obj, fieldNames)
            rangeValue = carbideField(obj.Model.State.carbide.lastBasic, fieldNames, []);
            rangeValues = numericVectorFromValue(rangeValue);
        end

        function values = carbidePresetNumericValues(obj, fieldName)
            values = [];
            presets = obj.carbidePresetArray();
            if isempty(presets)
                return;
            end

            for presetIndex = 1:numel(presets)
                value = carbideNumericField(presets(presetIndex), fieldName);
                if isfinite(value)
                    values(end + 1) = value; %#ok<AGROW>
                end
            end
        end

        function snapshot = currentCarbideSnapshot(obj)
            snapshot = struct( ...
                'connected', obj.areCarbideConnected(), ...
                'baseUrl', "", ...
                'selectedPreset', "", ...
                'actualPower', NaN, ...
                'actualFrequency', NaN, ...
                'actualPpDivider', NaN, ...
                'targetPpDivider', NaN, ...
                'actualPulseDuration', NaN, ...
                'targetPulseDuration', NaN, ...
                'pulseEnergyUj', NaN, ...
                'isOutputEnabled', [], ...
                'shutterState', "", ...
                'lastError', "");

            if ~isfield(obj.Model.State, 'carbide') || ~isstruct(obj.Model.State.carbide)
                return;
            end
            if isfield(obj.Model.State.carbide, 'baseUrl')
                snapshot.baseUrl = string(obj.Model.State.carbide.baseUrl);
            end
            if isfield(obj.Model.State.carbide, 'lastError')
                snapshot.lastError = string(obj.Model.State.carbide.lastError);
            end
            if ~snapshot.connected || ~isfield(obj.Model.State.carbide, 'lastBasic') || isempty(obj.Model.State.carbide.lastBasic)
                return;
            end

            basic = obj.Model.State.carbide.lastBasic;
            snapshot.selectedPreset = string(obj.formatCarbideSelectedPreset());
            snapshot.actualPower = carbideNumericField(basic, ["ActualOutputPower", "OutputPower", "ActualPower"]);
            snapshot.actualFrequency = carbideNumericField(basic, ["ActualOutputFrequency", "ActualFrequency", "OutputFrequency"]);
            snapshot.actualPpDivider = carbideNumericField(basic, ["ActualPpDivider", "ActualPPDivider", "PpDivider"]);
            snapshot.targetPpDivider = carbideNumericField(basic, ["TargetPpDivider", "TargetPPDivider"]);
            snapshot.actualPulseDuration = carbideNumericField(basic, ["ActualPulseDuration", "PulseDuration"]);
            snapshot.targetPulseDuration = carbideNumericField(basic, "TargetPulseDuration");
            snapshot.pulseEnergyUj = carbidePulseEnergyMicroJoules(basic);
            snapshot.isOutputEnabled = carbideField(basic, "IsOutputEnabled", []);
            snapshot.shutterState = carbideShutterStateText(basic);
        end

        function logCarbideRunStartSnapshot(obj)
            if ~obj.areCarbideConnected()
                obj.Ports.logMessage('Carbide run start snapshot: Disconnected.');
                return;
            end

            try
                obj.refreshCarbideStatusOnce();
                snapshot = obj.currentCarbideSnapshot();
                obj.Ports.logMessage(sprintf('Carbide run start snapshot: %s', char(formatCarbideSnapshot(snapshot))));
                obj.Ports.logMessage(sprintf('Carbide Basic JSON at run start: %s', compactJsonText(obj.Model.State.carbide.lastBasic)));
            catch ME
                obj.Model.State.carbide.lastError = string(ME.message);
                obj.Ports.logMessage(sprintf('Carbide run start snapshot unavailable: %s', compactErrorMessage(ME)));
            end
        end

        function autoStandbyAfterFinishedRun(obj)
            if ~obj.isAutoStandbyAfterRunEnabled()
                return;
            end

            if ~isfield(obj.Model.Config, 'carbide') || ...
                    (isfield(obj.Model.Config.carbide, 'enabled') && ~logical(obj.Model.Config.carbide.enabled))
                obj.Ports.logMessage('Auto standby after run skipped: Carbide control is disabled.');
                return;
            end

            if ~obj.areCarbideConnected()
                obj.Ports.logMessage('Auto standby after run skipped: Carbide is not connected.');
                return;
            end

            obj.Ports.logMessage('Auto standby after run requested.');
            try
                obj.standbyCarbideImpl();
            catch ME
                obj.Ports.reportError('Auto standby after run failed', ME);
            end
            obj.Ports.syncAll();
        end

        function tf = isAutoStandbyAfterRunEnabled(obj)
            tf = isfield(obj.Model.Ui, 'AutoStandbyAfterRunCheckBox') && ...
                logical(obj.Model.Ui.AutoStandbyAfterRunCheckBox.Value);
        end

        function textValue = autoStandbyAfterRunSummaryText(obj)
            textValue = ternary(obj.isAutoStandbyAfterRunEnabled(), 'Yes', 'No');
        end

        function syncCarbideStateIndicator(obj, carbideConnected)
            [stateText, stateColor, tooltipText] = obj.carbideStateStatus(carbideConnected);
            obj.Model.Ui.CarbideStateLamp.Color = stateColor;
            obj.Model.Ui.CarbideStateStatusLabel.Text = sprintf('Carbide State: %s', char(stateText));
            if isprop(obj.Model.Ui.CarbideStateLamp, 'Tooltip')
                obj.Model.Ui.CarbideStateLamp.Tooltip = tooltipText;
            end
            obj.Model.Ui.CarbideStateStatusLabel.Tooltip = tooltipText;
        end

        function syncCarbideShutterIndicator(obj, carbideConnected)
            [shutterText, shutterColor, tooltipText] = obj.carbideShutterStatus(carbideConnected);
            obj.Model.Ui.CarbideShutterLamp.Color = shutterColor;
            obj.Model.Ui.CarbideShutterStatusLabel.Text = sprintf('Shutter: %s', char(shutterText));
            if isprop(obj.Model.Ui.CarbideShutterLamp, 'Tooltip')
                obj.Model.Ui.CarbideShutterLamp.Tooltip = tooltipText;
            end
            obj.Model.Ui.CarbideShutterStatusLabel.Tooltip = tooltipText;
        end

        function syncCarbideStatusBarMetrics(obj, carbideConnected)
            powerText = '-';
            pulseEnergyText = '-';

            if carbideConnected && isfield(obj.Model.State.carbide, 'lastBasic') && ~isempty(obj.Model.State.carbide.lastBasic)
                basic = obj.Model.State.carbide.lastBasic;
                powerText = obj.Ports.appendUnit(formatCarbideNumericField(basic, ["ActualOutputPower", "OutputPower", "ActualPower"]), 'W');
                pulseEnergyText = obj.Ports.appendUnit(formatCarbidePulseEnergyField(basic), 'uJ');
            end

            obj.Model.Ui.CarbidePowerStatusLabel.Text = sprintf('Power: %s', powerText);
            obj.Model.Ui.CarbidePulseEnergyStatusLabel.Text = sprintf('Pulse Energy: %s', pulseEnergyText);
        end

        function tooltip = carbideStatusTooltip(obj)
            tooltip = '';
            if ~isfield(obj.Model.State, 'carbide') || ~isstruct(obj.Model.State.carbide)
                return;
            end

            if obj.areCarbideConnected() && isfield(obj.Model.State.carbide, 'baseUrl') && strlength(string(obj.Model.State.carbide.baseUrl)) > 0
                tooltip = char(obj.Model.State.carbide.baseUrl);
            elseif isfield(obj.Model.State.carbide, 'lastError') && strlength(string(obj.Model.State.carbide.lastError)) > 0
                tooltip = char(obj.Model.State.carbide.lastError);
            end
        end

        function tf = areCarbideConnected(obj)
            tf = isfield(obj.Model.State, 'carbide') && isstruct(obj.Model.State.carbide) && ...
                isfield(obj.Model.State.carbide, 'connected') && logical(obj.Model.State.carbide.connected);
        end

        function pulseEnergyUj = cachedCarbidePulseEnergyMicroJoules(obj)
            pulseEnergyUj = NaN;
            if ~obj.areCarbideConnected() || ~isfield(obj.Model.State.carbide, 'lastBasic') || isempty(obj.Model.State.carbide.lastBasic)
                return;
            end
            pulseEnergyUj = carbidePulseEnergyMicroJoules(obj.Model.State.carbide.lastBasic);
        end

    end

    methods (Access = private)
        function varargout = runCarbideRequest(obj, requestFcn)
            if obj.RequestInProgress
                error('lw:CarbideRequestBusy', 'Another Carbide request is already in progress.');
            end

            obj.RequestInProgress = true;
            cleanupObj = onCleanup(@() obj.releaseCarbideRequest());
            if nargout == 0
                requestFcn();
                return;
            end
            [varargout{1:nargout}] = requestFcn();
        end

        function releaseCarbideRequest(obj)
            obj.RequestInProgress = false;
        end
    end
end
