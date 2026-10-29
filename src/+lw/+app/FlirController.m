classdef FlirController < handle
    %FLIRCONTROLLER Own FLIR connection, settings, live view, and acquisition.

    properties (SetAccess = private)
        Model
        Ports
    end

    methods
        function obj = FlirController(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("FlirController", ports, [ ...
                "logMessage", "mergeUi", "runUiAction", "showImagingFrame", "uiBuildHelpers"]);
        end

        function onRefreshFlirDevices(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.refreshFlirDevicesImpl(), 'Failed to refresh FLIR devices');
        end

        function refreshFlirDevicesImpl(obj)
            obj.Model.State.flir = obj.Model.Services.flir.refreshDevices(obj.Model.State.flir);
            obj.refreshFlirDeviceDropDown();
            if isempty(obj.Model.State.flir.devices)
                obj.Ports.logMessage('No FLIR/Spinnaker camera detected. Check USB cable and close SpinView.');
            else
                obj.Ports.logMessage(sprintf('Detected %d FLIR/Spinnaker camera(s).', numel(obj.Model.State.flir.devices)));
            end
        end

        function onConnectFlir(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.connectFlirImpl(), 'Failed to connect FLIR camera');
        end

        function connectFlirImpl(obj)
            deviceIndex = obj.selectedFlirDeviceIndex();
            if isempty(deviceIndex)
                obj.Model.State.flir = obj.Model.Services.flir.refreshDevices(obj.Model.State.flir);
                obj.refreshFlirDeviceDropDown();
                deviceIndex = obj.selectedFlirDeviceIndex();
            end
            if isempty(deviceIndex)
                error('No FLIR camera selected.');
            end

            selectedLabel = obj.selectedFlirCameraLabel();
            obj.Model.Ui.FlirStatusLabel.Text = 'Connecting...';
            setEnable(obj.Model.Ui.FlirRefreshButton, false);
            setEnable(obj.Model.Ui.FlirDeviceDropDown, false);
            setEnable(obj.Model.Ui.FlirConnectButton, false);
            obj.Ports.logMessage(sprintf('Connecting FLIR camera: %s.', selectedLabel));
            obj.Model.Services.ui.drawnow();

            obj.Model.State.flir = obj.Model.Services.flir.connect(obj.Model.State.flir, deviceIndex);
            obj.syncFlirSettingFieldsFromCamera();
            obj.refreshFlirRoiLimits(true);
            obj.flirLive('update');
            obj.Ports.logMessage(sprintf('FLIR camera connected: %s.', selectedLabel));
        end

        function onDisconnectFlir(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.disconnectFlirImpl(), 'Failed to disconnect FLIR camera');
        end

        function disconnectFlirImpl(obj)
            if obj.Model.Ui.FlirRoiEditActive
                obj.endFlirLiveRoiEdit();
                obj.syncFlirRoiFieldsFromSelection();
            end
            obj.flirLive('stop', false);
            obj.Model.State.flir = obj.Model.Services.flir.disconnect(obj.Model.State.flir);
            obj.Model.FlirRoiLimits = struct();
            obj.refreshFlirDeviceDropDown();
            obj.Model.ImagingCurrentText = "Idle";
            obj.Model.ImagingProgressText = "0 / 0";
            obj.flirLive('update');
            obj.Ports.logMessage('FLIR camera disconnected.');
        end

        function onApplyFlirExposure(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.applyFlirExposureImpl(), 'Failed to apply FLIR exposure');
        end

        function applyFlirExposureImpl(obj)
            obj.requireFlirConnected();
            resumeLive = obj.flirLive('pause', 'Paused for exposure');
            liveCleanupObj = onCleanup(@() obj.flirLive('resume', resumeLive));
            exposureUs = positiveScalar(obj.Model.Ui.FlirExposureField.Value, 'FLIR exposure');
            [obj.Model.State.flir, actualExposureUs] = obj.Model.Services.flir.setExposure( ...
                obj.Model.State.flir, exposureUs);
            obj.Model.Ui.FlirExposureField.Value = actualExposureUs;
            obj.syncFlirLiveWindowFieldsFromMain();
            obj.Ports.logMessage(sprintf('FLIR ExposureTime set to %.6g us.', actualExposureUs));
            clear liveCleanupObj
        end

        function onApplyFlirGain(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.applyFlirGainImpl(), 'Failed to apply FLIR gain');
        end

        function applyFlirGainImpl(obj)
            obj.requireFlirConnected();
            resumeLive = obj.flirLive('pause', 'Paused for gain');
            liveCleanupObj = onCleanup(@() obj.flirLive('resume', resumeLive));
            gain = nonnegativeScalar(obj.Model.Ui.FlirGainField.Value, 'FLIR gain');
            [obj.Model.State.flir, actualGain] = obj.Model.Services.flir.setGain( ...
                obj.Model.State.flir, gain);
            obj.Model.Ui.FlirGainField.Value = actualGain;
            obj.syncFlirLiveWindowFieldsFromMain();
            obj.Ports.logMessage(sprintf('FLIR Gain set to %.6g dB.', actualGain));
            clear liveCleanupObj
        end

        function onTestFlirCapture(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.testFlirCaptureImpl(), 'FLIR test capture failed');
        end

        function testFlirCaptureImpl(obj)
            obj.requireFlirConnected();
            resumeLive = obj.flirLive('pause', 'Paused for capture');
            liveCleanupObj = onCleanup(@() obj.flirLive('resume', resumeLive));
            options = struct( ...
                'timeoutMs', positiveInteger(obj.Model.Ui.ImagingTimeoutField.Value, 'FLIR capture timeout'), ...
                'useNativeResolution', true, ...
                'captureRegion', obj.flirCaptureRegion());
            [obj.Model.State.flir, frame, info] = obj.Model.Services.flir.capture( ...
                obj.Model.State.flir, options);
            obj.Ports.showImagingFrame(frame, sprintf('Test capture %s', char(datetime('now', 'Format', 'HH:mm:ss'))));
            obj.Model.ImagingCurrentText = sprintf('Captured %d x %d %s', info.Width, info.Height, info.PixelFormat);
            obj.Ports.logMessage(sprintf('FLIR test capture: %d x %d%s %s (%s).', ...
                info.Width, info.Height, obj.flirFrameOffsetText(info), info.PixelFormat, ...
                char(obj.flirInfoRegionName(info))));
            clear liveCleanupObj
        end

        function region = flirCaptureRegion(obj)
            region = obj.captureRegionForSelection(obj.flirRoiSelection());
        end

        function value = imagingConfigValue(obj, fieldName, fallbackValue)
            value = fallbackValue;
            if isfield(obj.Model.Config, 'imaging') && isfield(obj.Model.Config.imaging, fieldName) && ...
                    ~isempty(obj.Model.Config.imaging.(fieldName))
                value = obj.Model.Config.imaging.(fieldName);
            end
        end

        function regionName = flirInfoRegionName(~, info)
            regionName = "full";
            if isfield(info, 'RoiName') && ~isempty(info.RoiName)
                regionName = string(info.RoiName);
            end
        end

        function text = flirFrameOffsetText(~, info)
            text = '';
            if isstruct(info) && isfield(info, 'OffsetX') && isfield(info, 'OffsetY')
                text = sprintf(' @ (%d, %d)', round(double(info.OffsetX)), round(double(info.OffsetY)));
            end
        end

        function onApplyFlirRoi(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.applyFlirRoiImpl(), 'Failed to apply FLIR ROI');
        end

        function onCenterFlirRoi(obj, ~, ~)
            obj.Ports.runUiAction(@() obj.centerFlirRoiImpl(), 'Failed to center FLIR ROI');
        end

        function selection = flirRoiSelection(obj)
            selection = obj.Model.FlirRoiSelection;
            if ~isstruct(selection) || ~isfield(selection, 'Mode')
                selection = obj.defaultFlirRoiSelection();
            end
        end

        function selection = defaultFlirRoiSelection(obj)
            defaultRect = struct('OffsetX', 0, 'OffsetY', 0, 'Width', 512, 'Height', 512);
            selection = lw_flir_roi_selection( ...
                obj.imagingConfigValue('captureRegion', "full"), ...
                obj.imagingConfigValue('defaultCustomRoi', defaultRect));
        end

        function region = captureRegionForSelection(~, selection)
            if selection.Mode == "custom"
                region = struct( ...
                    'OffsetX', selection.OffsetX, ...
                    'OffsetY', selection.OffsetY, ...
                    'Width', selection.Width, ...
                    'Height', selection.Height);
            else
                region = selection.Mode;
            end
        end

        function loadSavedFlirRoiSelection(obj)
            [obj.Model.FlirRoiSelection, message] = lw_flir_roi_selection_load( ...
                obj.imagingConfigValue('roiSettingsFile', ""), obj.defaultFlirRoiSelection());
            obj.syncFlirRoiFieldsFromSelection();
            obj.syncFlirRoiInfo();
            if strlength(message) > 0
                obj.Ports.logMessage(sprintf('%s FLIR ROI: %s.', char(message), char(obj.flirRoiSelectionText())));
            end
        end

        function saveFlirRoiSelection(obj)
            filePath = string(obj.imagingConfigValue('roiSettingsFile', ""));
            if strlength(filePath) == 0
                return;
            end
            try
                lw_flir_roi_selection_save(filePath, obj.flirRoiSelection(), obj.selectedFlirCameraLabel());
            catch ME
                obj.Ports.logMessage(sprintf('FLIR ROI applied but could not be saved: %s', compactErrorMessage(ME)));
            end
        end

        function applyFlirRoiImpl(obj)
            obj.requireFlirConnected();
            requested = obj.flirRoiSelectionFromUi();
            resumeLive = obj.flirLive('pause', 'Paused for ROI');
            resumeLive = obj.endFlirLiveRoiEdit() || resumeLive;
            liveCleanupObj = onCleanup(@() obj.flirLive('resume', resumeLive));

            [obj.Model.State.flir, ~, ~, roi] = obj.Model.Services.flir.setCaptureRegion( ...
                obj.Model.State.flir, obj.captureRegionForSelection(requested));
            if isfield(roi, 'Name') && string(roi.Name) == "current-read-only"
                obj.syncFlirRoiFieldsFromSelection();
                error('FLIR ROI nodes are read-only; the camera kept %s.', char(obj.formatFlirRoiRect(roi)));
            end

            applied = requested;
            if requested.Mode == "custom"
                applied = lw_flir_roi_selection("custom", roi);
            end
            obj.Model.FlirRoiSelection = applied;
            obj.syncFlirRoiFieldsFromSelection();
            obj.refreshFlirRoiLimits(false);
            obj.saveFlirRoiSelection();
            if requested.Mode == "custom" && ...
                    ~isequal(obj.flirRoiRectVector(applied), obj.flirRoiRectVector(requested))
                obj.Ports.logMessage(sprintf('FLIR ROI snapped to camera steps: requested %s, applied %s.', ...
                    char(obj.formatFlirRoiRect(requested)), char(obj.formatFlirRoiRect(applied))));
            end
            obj.Ports.logMessage(sprintf('FLIR ROI applied and saved: %s (camera %s).', ...
                char(obj.flirRoiSelectionText()), char(obj.formatFlirRoiRect(roi))));
            clear liveCleanupObj
        end

        function centerFlirRoiImpl(obj)
            limits = obj.requireFlirRoiLimits();
            rect = obj.flirRoiRectFromUi();
            rect.OffsetX = (limits.SensorWidth - rect.Width) / 2;
            rect.OffsetY = (limits.SensorHeight - rect.Height) / 2;
            obj.setFlirRoiFields(lw_flir_normalize_roi(rect, limits));
            obj.syncFlirRoiInfo();
        end

        function limits = refreshFlirRoiLimits(obj, shouldLog)
            limits = struct();
            obj.Model.FlirRoiLimits = struct();
            if obj.isFlirConnected()
                try
                    limits = obj.Model.Services.flir.readRoiLimits(obj.Model.State.flir.nodeMap);
                    obj.Model.FlirRoiLimits = limits;
                    if shouldLog
                        obj.Ports.logMessage(sprintf( ...
                            'FLIR sensor %d x %d; ROI steps: width %d, height %d, offset X %d, offset Y %d.', ...
                            limits.SensorWidth, limits.SensorHeight, limits.WidthIncrement, ...
                            limits.HeightIncrement, limits.OffsetXIncrement, limits.OffsetYIncrement));
                    end
                catch ME
                    if shouldLog
                        obj.Ports.logMessage(sprintf('FLIR ROI limits could not be read: %s', compactErrorMessage(ME)));
                    end
                end
            end
            obj.syncFlirRoiInfo();
        end

        function limits = requireFlirRoiLimits(obj)
            obj.requireFlirConnected();
            limits = obj.Model.FlirRoiLimits;
            if ~isstruct(limits) || ~isfield(limits, 'SensorWidth')
                limits = obj.Model.Services.flir.readRoiLimits(obj.Model.State.flir.nodeMap);
                obj.Model.FlirRoiLimits = limits;
            end
        end

        function selection = flirRoiSelectionFromUi(obj)
            selection = lw_flir_roi_selection( ...
                obj.flirRoiModeFromLabel(obj.Model.Ui.FlirRoiModeDropDown.Value), obj.flirRoiRectFromUi());
        end

        function rect = flirRoiRectFromUi(obj)
            rect = struct( ...
                'OffsetX', obj.Model.Ui.FlirRoiOffsetXField.Value, ...
                'OffsetY', obj.Model.Ui.FlirRoiOffsetYField.Value, ...
                'Width', obj.Model.Ui.FlirRoiWidthField.Value, ...
                'Height', obj.Model.Ui.FlirRoiHeightField.Value);
        end

        function setFlirRoiFields(obj, rect)
            obj.Model.Ui.FlirRoiOffsetXField.Value = rect.OffsetX;
            obj.Model.Ui.FlirRoiOffsetYField.Value = rect.OffsetY;
            obj.Model.Ui.FlirRoiWidthField.Value = rect.Width;
            obj.Model.Ui.FlirRoiHeightField.Value = rect.Height;
        end

        function syncFlirRoiFieldsFromSelection(obj)
            if ~obj.hasValidUiControl('FlirRoiModeDropDown')
                return;
            end
            selection = obj.flirRoiSelection();
            obj.Model.Ui.FlirRoiModeDropDown.Value = obj.flirRoiModeLabel(selection.Mode);
            obj.setFlirRoiFields(selection);
        end

        function tf = isFlirRoiCustomModeSelected(obj)
            tf = obj.hasValidUiControl('FlirRoiModeDropDown') && ...
                obj.flirRoiModeFromLabel(obj.Model.Ui.FlirRoiModeDropDown.Value) == "custom";
        end

        function tf = hasUnappliedFlirRoiEdits(obj)
            tf = false;
            if ~obj.hasValidUiControl('FlirRoiModeDropDown')
                return;
            end
            try
                pending = obj.flirRoiSelectionFromUi();
            catch
                tf = true;
                return;
            end
            applied = obj.flirRoiSelection();
            tf = pending.Mode ~= applied.Mode || (pending.Mode == "custom" && ...
                ~isequal(obj.flirRoiRectVector(pending), obj.flirRoiRectVector(applied)));
        end

        function text = flirRoiSelectionText(obj)
            selection = obj.flirRoiSelection();
            switch selection.Mode
                case "custom"
                    text = obj.formatFlirRoiRect(selection);
                case "top-left-quarter"
                    text = "Top-left quarter";
                otherwise
                    text = "Full sensor";
            end
        end

        function text = flirRoiPreflightText(obj)
            text = obj.flirRoiSelectionText();
            if obj.hasUnappliedFlirRoiEdits()
                text = text + " (unapplied ROI edits in the panel are ignored)";
            end
        end

        function syncFlirRoiInfo(obj)
            if obj.hasValidUiControl('FlirRoiInfoLabel')
                limits = obj.Model.FlirRoiLimits;
                if obj.isFlirConnected() && isstruct(limits) && isfield(limits, 'SensorWidth')
                    text = sprintf('Sensor %d x %d | Using %s', ...
                        limits.SensorWidth, limits.SensorHeight, char(obj.flirRoiSelectionText()));
                    if obj.hasUnappliedFlirRoiEdits()
                        text = [text, ' | edits not applied'];
                    end
                else
                    text = 'Connect FLIR to read the sensor size.';
                end
                obj.Model.Ui.FlirRoiInfoLabel.Text = text;
            end
            if obj.hasValidUiControl('FlirLiveRoiLabel')
                obj.Model.Ui.FlirLiveRoiLabel.Text = char(obj.flirRoiSelectionText());
            end
        end

        function drawFlirLiveRoiImpl(obj)
            obj.requireFlirConnected();
            if ~obj.isFlirLiveWindowOpen() || ~obj.hasValidUiControl('FlirLiveAxes')
                error('Open the Live FLIR window before drawing an ROI.');
            end
            if exist('images.roi.Rectangle', 'class') ~= 8
                error('Draw ROI needs the Image Processing Toolbox; type the ROI in the FLIR Camera panel instead.');
            end

            wasLive = obj.Model.Ui.FlirLiveEnabled;
            resumeLive = obj.endFlirLiveRoiEdit();
            resumeLive = obj.flirLive('pause', 'Drawing ROI') || resumeLive;
            try
                limits = obj.requireFlirRoiLimits();
                [frame, info] = obj.flirRoiDrawFrame(wasLive);
            catch ME
                obj.flirLive('resume', resumeLive);
                rethrow(ME);
            end

            obj.showFlirLiveFrame(frame, info);
            obj.Model.Ui.FlirRoiEditBase = struct( ...
                'OffsetX', obj.flirInfoOffset(info, 'OffsetX'), ...
                'OffsetY', obj.flirInfoOffset(info, 'OffsetY'));
            rect = images.roi.Rectangle(obj.Model.Ui.FlirLiveAxes, ...
                'Color', [1, 0.25, 0.25], ...
                'FaceAlpha', 0, ...
                'LineWidth', 1.5);
            obj.Model.Ui.FlirRoiDrawRect = rect;
            obj.Model.Ui.FlirRoiEditActive = true;
            obj.Model.Ui.FlirRoiEditResumeLive = resumeLive;
            obj.flirLive('update', 'Drawing ROI');
            obj.setFlirLiveAxesTitle('Drag a rectangle over the region to keep (Esc cancels)');
            try
                draw(rect);
            catch
            end

            % Apply, Cancel, or closing the window during the drag already ended the edit.
            if ~obj.Model.Ui.FlirRoiEditActive || ~isequal(obj.Model.Ui.FlirRoiDrawRect, rect)
                return;
            end
            if ~isValidUiHandle(rect) || isempty(rect.Position) || any(rect.Position(3:4) <= 0)
                obj.cancelFlirLiveRoiEditImpl();
                return;
            end

            addlistener(rect, 'ROIMoved', @(source, ~) obj.onFlirLiveRoiMoved(source));
            obj.updateFlirRoiFieldsFromLiveRect(rect, limits);
            obj.flirLive('update', 'ROI drawn');
            obj.setFlirLiveAxesTitle('Adjust the rectangle, then Apply ROI or Cancel');
            obj.Ports.logMessage(sprintf('FLIR ROI drawn: %s. Click Apply ROI to use it.', ...
                char(obj.formatFlirRoiRect(obj.flirRoiRectFromUi()))));
        end

        function [frame, info] = flirRoiDrawFrame(obj, wasLive)
            flirState = obj.Model.State.flir;
            if wasLive && isfield(flirState, 'lastFrame') && ~isempty(flirState.lastFrame) && ...
                    isfield(flirState, 'lastFrameInfo') && isfield(flirState.lastFrameInfo, 'OffsetX')
                frame = flirState.lastFrame;
                info = flirState.lastFrameInfo;
                return;
            end
            options = struct( ...
                'timeoutMs', positiveInteger(obj.Model.Ui.ImagingTimeoutField.Value, 'FLIR capture timeout'), ...
                'useNativeResolution', true, ...
                'captureRegion', obj.flirCaptureRegion());
            [obj.Model.State.flir, frame, info] = obj.Model.Services.flir.capture( ...
                obj.Model.State.flir, options);
        end

        function value = flirInfoOffset(~, info, fieldName)
            value = 0;
            if isfield(info, fieldName) && isfinite(double(info.(fieldName)))
                value = round(double(info.(fieldName)));
            end
        end

        function onFlirLiveRoiMoved(obj, source)
            try
                if ~obj.Model.Ui.FlirRoiEditActive || ~isValidUiHandle(source) || isempty(source.Position)
                    return;
                end
                obj.updateFlirRoiFieldsFromLiveRect(source, obj.requireFlirRoiLimits());
            catch ME
                obj.Ports.logMessage(sprintf('FLIR ROI update failed: %s', compactErrorMessage(ME)));
            end
        end

        function updateFlirRoiFieldsFromLiveRect(obj, rect, limits)
            % Axes pixel centers sit on integers, so the left image edge is x = 0.5.
            base = obj.Model.Ui.FlirRoiEditBase;
            position = double(rect.Position);
            roi = lw_flir_normalize_roi(struct( ...
                'OffsetX', base.OffsetX + position(1) - 0.5, ...
                'OffsetY', base.OffsetY + position(2) - 0.5, ...
                'Width', position(3), ...
                'Height', position(4)), limits);
            rect.Position = [roi.OffsetX - base.OffsetX + 0.5, roi.OffsetY - base.OffsetY + 0.5, ...
                roi.Width, roi.Height];
            rect.Label = sprintf('%d x %d', roi.Width, roi.Height);
            obj.Model.Ui.FlirRoiModeDropDown.Value = obj.flirRoiModeLabel("custom");
            obj.setFlirRoiFields(roi);
            obj.syncFlirRoiInfo();
        end

        function applyFlirLiveRoiImpl(obj)
            obj.applyFlirRoiImpl();
            obj.showFlirLiveSnapshotIfIdle();
        end

        function applyFlirFullFrameImpl(obj)
            obj.requireFlirConnected();
            obj.Model.Ui.FlirRoiModeDropDown.Value = obj.flirRoiModeLabel("full");
            obj.applyFlirRoiImpl();
            obj.showFlirLiveSnapshotIfIdle();
        end

        function showFlirLiveSnapshotIfIdle(obj)
            if obj.Model.Ui.FlirLiveEnabled || ~obj.isFlirLiveWindowOpen() || ~obj.isFlirConnected()
                return;
            end
            [frame, info] = obj.flirRoiDrawFrame(false);
            obj.showFlirLiveFrame(frame, info);
        end

        function cancelFlirLiveRoiEditImpl(obj)
            wasEditing = obj.Model.Ui.FlirRoiEditActive;
            resumeLive = obj.endFlirLiveRoiEdit();
            obj.syncFlirRoiFieldsFromSelection();
            obj.syncFlirRoiInfo();
            if resumeLive
                obj.flirLive('resume', true);
            else
                obj.flirLive('update');
                if wasEditing
                    obj.setFlirLiveAxesTitle('ROI drawing cancelled');
                end
            end
            if wasEditing
                obj.Ports.logMessage('FLIR ROI drawing cancelled.');
            end
        end

        function resumeLive = endFlirLiveRoiEdit(obj)
            resumeLive = logical(obj.Model.Ui.FlirRoiEditResumeLive);
            rect = obj.Model.Ui.FlirRoiDrawRect;
            obj.Model.Ui.FlirRoiDrawRect = [];
            obj.Model.Ui.FlirRoiEditActive = false;
            obj.Model.Ui.FlirRoiEditResumeLive = false;
            try
                if isValidUiHandle(rect)
                    delete(rect);
                end
            catch
            end
        end

        function tf = isFlirLiveRoiDrawn(obj)
            rect = obj.Model.Ui.FlirRoiDrawRect;
            tf = obj.Model.Ui.FlirRoiEditActive && isValidUiHandle(rect) && ~isempty(rect.Position);
        end

        function label = flirRoiModeLabel(~, mode)
            switch string(mode)
                case "custom"
                    label = 'Custom';
                case "top-left-quarter"
                    label = 'Top-left quarter';
                otherwise
                    label = 'Full sensor';
            end
        end

        function mode = flirRoiModeFromLabel(~, label)
            switch string(label)
                case "Custom"
                    mode = "custom";
                case "Top-left quarter"
                    mode = "top-left-quarter";
                otherwise
                    mode = "full";
            end
        end

        function values = flirRoiRectVector(~, rect)
            values = double([rect.OffsetX, rect.OffsetY, rect.Width, rect.Height]);
        end

        function text = formatFlirRoiRect(~, rect)
            text = string(sprintf('%d x %d @ (%d, %d)', ...
                round(double(rect.Width)), round(double(rect.Height)), ...
                round(double(rect.OffsetX)), round(double(rect.OffsetY))));
        end

        function gain = flirLiveGainValue(obj)
            gain = 0;
            if isfield(obj.Model.Config, 'imaging') && isfield(obj.Model.Config.imaging, 'defaultGain') && ...
                    ~isempty(obj.Model.Config.imaging.defaultGain)
                gain = double(obj.Model.Config.imaging.defaultGain);
            end
            if isfield(obj.Model.State.flir, 'lastGain') && ~isempty(obj.Model.State.flir.lastGain) && ...
                    isfinite(double(obj.Model.State.flir.lastGain))
                gain = double(obj.Model.State.flir.lastGain);
            end
        end

        function exposureUs = flirLiveExposureValue(obj)
            exposureUs = NaN;
            if isfield(obj.Model.Config, 'imaging') && isfield(obj.Model.Config.imaging, 'defaultExposureUs') && ...
                    ~isempty(obj.Model.Config.imaging.defaultExposureUs)
                exposureUs = double(obj.Model.Config.imaging.defaultExposureUs);
            end
            if isfield(obj.Model.State.flir, 'lastExposureTimeUs') && ~isempty(obj.Model.State.flir.lastExposureTimeUs) && ...
                    isfinite(double(obj.Model.State.flir.lastExposureTimeUs))
                exposureUs = double(obj.Model.State.flir.lastExposureTimeUs);
            end
        end

        function refreshFlirLiveReadouts(obj, shouldReadCamera)
            if nargin < 2
                shouldReadCamera = false;
            end
            if ~obj.hasValidUiControl('FlirLiveCurrentExposureLabel') && ...
                    ~obj.hasValidUiControl('FlirLiveCurrentGainLabel')
                return;
            end

            exposureUs = obj.flirLiveExposureValue();
            gain = obj.flirLiveGainValue();
            if shouldReadCamera && obj.isFlirConnected()
                [exposureUs, didReadExposure] = obj.readFlirFloatSetting('ExposureTime', exposureUs);
                if didReadExposure
                    obj.Model.State.flir.lastExposureTimeUs = exposureUs;
                end

                [gain, didReadGain] = obj.readFlirFloatSetting('Gain', gain);
                if didReadGain
                    obj.Model.State.flir.lastGain = gain;
                end
            end

            if obj.hasValidUiControl('FlirLiveCurrentExposureLabel')
                obj.Model.Ui.FlirLiveCurrentExposureLabel.Text = obj.formatFlirLiveSettingValue(exposureUs, 'us');
            end
            if obj.hasValidUiControl('FlirLiveCurrentGainLabel')
                obj.Model.Ui.FlirLiveCurrentGainLabel.Text = obj.formatFlirLiveSettingValue(gain, 'dB');
            end
        end

        function [value, didRead] = readFlirFloatSetting(obj, nodeName, fallbackValue)
            didRead = false;
            try
                value = obj.Model.Services.flir.readFloatNode( ...
                    obj.Model.State.flir.nodeMap, char(nodeName), fallbackValue);
                numericValue = double(value);
                didRead = isscalar(numericValue) && isfinite(numericValue);
                if didRead
                    value = numericValue;
                else
                    value = fallbackValue;
                end
            catch
                value = fallbackValue;
            end
        end

        function syncFlirSettingFieldsFromCamera(obj)
            if ~obj.isFlirConnected()
                return;
            end

            [exposureUs, didReadExposure] = obj.readFlirFloatSetting('ExposureTime', obj.flirLiveExposureValue());
            if didReadExposure
                obj.Model.State.flir.lastExposureTimeUs = exposureUs;
                if obj.hasValidUiControl('FlirExposureField')
                    obj.Model.Ui.FlirExposureField.Value = exposureUs;
                end
            end

            [gain, didReadGain] = obj.readFlirFloatSetting('Gain', obj.flirLiveGainValue());
            if didReadGain
                obj.Model.State.flir.lastGain = gain;
                if obj.hasValidUiControl('FlirGainField')
                    obj.Model.Ui.FlirGainField.Value = gain;
                end
            end

            obj.syncFlirLiveWindowFieldsFromMain();
            if didReadExposure || didReadGain
                exposureText = '-';
                gainText = '-';
                if didReadExposure
                    exposureText = obj.formatFlirLiveSettingValue(exposureUs, 'us');
                end
                if didReadGain
                    gainText = obj.formatFlirLiveSettingValue(gain, 'dB');
                end
                obj.Ports.logMessage(sprintf('FLIR current settings loaded: ExposureTime %s, Gain %s.', ...
                    char(exposureText), char(gainText)));
            else
                obj.Ports.logMessage('FLIR current exposure/gain could not be read; keeping existing field values.');
            end
        end

        function text = formatFlirLiveSettingValue(~, value, unitText)
            text = '-';
            try
                numericValue = double(value);
            catch
                return;
            end
            if isscalar(numericValue) && isfinite(numericValue)
                text = sprintf('%.6g %s', numericValue, unitText);
            end
        end

        function openFlirLiveWindowImpl(obj)
            obj.requireFlirConnected();
            if obj.isFlirLiveWindowOpen()
                obj.syncFlirLiveWindowFieldsFromMain();
                obj.flirLive('update');
                try
                    figure(obj.Model.Ui.FlirLiveFigure);
                catch
                    try
                        obj.Model.Ui.FlirLiveFigure.Visible = 'on';
                    catch
                    end
                end
                return;
            end

            obj.buildFlirLiveWindow();
            obj.syncFlirLiveWindowFieldsFromMain();
            obj.flirLive('update');
        end

        function buildFlirLiveWindow(obj)
            callbacks = struct( ...
                'closeWindow', @(~, ~) obj.flirLive('close-window'), ...
                'toggleLive', @(~, ~) obj.Ports.runUiAction(@() obj.flirLive('toggle'), ...
                    'Failed to toggle FLIR live view'), ...
                'applyExposure', @(~, ~) obj.Ports.runUiAction(@() obj.applyFlirLiveExposureImpl(), ...
                    'Failed to apply FLIR live exposure'), ...
                'applyGain', @(~, ~) obj.Ports.runUiAction(@() obj.applyFlirLiveGainImpl(), ...
                    'Failed to apply FLIR live gain'), ...
                'timeoutChanged', @(value) obj.Ports.runUiAction(@() obj.setFlirLiveTimeoutMs(value), ...
                    'Failed to update FLIR live timeout'), ...
                'periodChanged', @(value) obj.Ports.runUiAction(@() obj.setFlirLivePeriodSeconds(value), ...
                    'Failed to update FLIR live period'), ...
                'markerChanged', @(~, ~) obj.redrawLastFlirLiveFrame(), ...
                'drawRoi', @(~, ~) obj.Ports.runUiAction(@() obj.drawFlirLiveRoiImpl(), ...
                    'Failed to draw FLIR ROI'), ...
                'fullFrameRoi', @(~, ~) obj.Ports.runUiAction(@() obj.applyFlirFullFrameImpl(), ...
                    'Failed to switch FLIR to full frame'), ...
                'applyRoi', @(~, ~) obj.Ports.runUiAction(@() obj.applyFlirLiveRoiImpl(), ...
                    'Failed to apply FLIR ROI'), ...
                'cancelRoi', @(~, ~) obj.Ports.runUiAction(@() obj.cancelFlirLiveRoiEditImpl(), ...
                    'Failed to cancel FLIR ROI drawing'));
            options = struct('selectedCameraLabel', obj.selectedFlirCameraLabel());
            obj.Ports.mergeUi(lw_build_flir_live_window(obj.Model.Figure, callbacks, obj.Ports.uiBuildHelpers(), options));
        end

        function syncFlirLiveWindowFieldsFromMain(obj)
            if obj.hasValidUiControl('FlirLiveExposureField') && obj.hasValidUiControl('FlirExposureField')
                obj.Model.Ui.FlirLiveExposureField.Value = obj.Model.Ui.FlirExposureField.Value;
            end
            if obj.hasValidUiControl('FlirLiveGainField')
                if obj.hasValidUiControl('FlirGainField')
                    obj.Model.Ui.FlirLiveGainField.Value = obj.Model.Ui.FlirGainField.Value;
                else
                    obj.Model.Ui.FlirLiveGainField.Value = obj.flirLiveGainValue();
                end
            end
            if obj.hasValidUiControl('FlirLiveTimeoutField')
                obj.Model.Ui.FlirLiveTimeoutField.Value = obj.Model.Ui.FlirLiveTimeoutMs;
            end
            if obj.hasValidUiControl('FlirLivePeriodField')
                obj.Model.Ui.FlirLivePeriodField.Value = obj.Model.Ui.FlirLivePeriodSeconds;
            end
            if obj.hasValidUiControl('FlirLiveCameraLabel')
                obj.Model.Ui.FlirLiveCameraLabel.Text = obj.selectedFlirCameraLabel();
            end
            obj.refreshFlirLiveReadouts(true);
        end

        function applyFlirLiveExposureImpl(obj)
            obj.requireFlirConnected();
            if ~obj.hasValidUiControl('FlirLiveExposureField')
                return;
            end
            obj.Model.Ui.FlirExposureField.Value = positiveScalar(obj.Model.Ui.FlirLiveExposureField.Value, 'FLIR live exposure');
            obj.applyFlirExposureImpl();
            obj.syncFlirLiveWindowFieldsFromMain();
        end

        function applyFlirLiveGainImpl(obj)
            obj.requireFlirConnected();
            if ~obj.hasValidUiControl('FlirLiveGainField')
                return;
            end
            obj.Model.Ui.FlirGainField.Value = nonnegativeScalar(obj.Model.Ui.FlirLiveGainField.Value, 'FLIR live gain');
            obj.applyFlirGainImpl();
        end

        function setFlirLiveTimeoutMs(obj, rawValue)
            obj.Model.Ui.FlirLiveTimeoutMs = max(250, min(positiveInteger(rawValue, 'FLIR live timeout'), 750));
            if obj.hasValidUiControl('FlirLiveTimeoutField')
                obj.Model.Ui.FlirLiveTimeoutField.Value = obj.Model.Ui.FlirLiveTimeoutMs;
            end
        end

        function setFlirLivePeriodSeconds(obj, rawValue)
            obj.Model.Ui.FlirLivePeriodSeconds = max(0.05, min(positiveScalar(rawValue, 'FLIR live period'), 10));
            if obj.hasValidUiControl('FlirLivePeriodField')
                obj.Model.Ui.FlirLivePeriodField.Value = obj.Model.Ui.FlirLivePeriodSeconds;
            end
            if ~isempty(obj.Model.Ui.FlirLiveTimerHandle) && isvalid(obj.Model.Ui.FlirLiveTimerHandle)
                wasRunning = strcmp(obj.Model.Ui.FlirLiveTimerHandle.Running, 'on');
                if wasRunning
                    stop(obj.Model.Ui.FlirLiveTimerHandle);
                end
                obj.Model.Ui.FlirLiveTimerHandle.Period = obj.Model.Ui.FlirLivePeriodSeconds;
                if wasRunning && obj.Model.Ui.FlirLiveEnabled
                    start(obj.Model.Ui.FlirLiveTimerHandle);
                end
            end
        end

        function varargout = flirLive(obj, action, varargin)
            action = string(action);
            outputValue = [];

            switch action
                case "toggle"
                    if obj.Model.Ui.FlirLiveEnabled
                        obj.flirLive('stop', true);
                    else
                        obj.flirLive('start', true);
                    end

                case "start"
                    shouldLog = nargin < 3 || logical(varargin{1});
                    if obj.Model.State.isBusy || obj.Model.State.isPaused || obj.Model.PausedManualMotionActive
                        error('FLIR live view can only be started while the app is idle.');
                    end
                    obj.requireFlirConnected();
                    if ~obj.isFlirLiveWindowOpen()
                        error('Open the Live FLIR window before starting live view.');
                    end
                    if obj.Model.Ui.FlirRoiEditActive
                        obj.endFlirLiveRoiEdit();
                        obj.syncFlirRoiFieldsFromSelection();
                    end
                    obj.Model.Ui.FlirLiveEnabled = true;
                    obj.Model.Ui.FlirLiveFrameCount = 0;
                    obj.Model.Ui.FlirLiveFailureCount = 0;
                    obj.Model.Ui.FlirLiveLastFrameTic = obj.Model.Services.clock.tic();
                    obj.flirLive('update', 'Starting');
                    try
                        if ~isfield(obj.Model.State.flir, 'isAcquiring') || ~logical(obj.Model.State.flir.isAcquiring)
                            [obj.Model.State.flir, ~, ~, regionInfo] = obj.Model.Services.flir.setCaptureRegion( ...
                                obj.Model.State.flir, obj.flirCaptureRegion());
                            if shouldLog && isfield(regionInfo, 'Name') && string(regionInfo.Name) == "current-read-only"
                                obj.Ports.logMessage('FLIR ROI nodes are read-only; live view is using the current camera ROI.');
                            end
                            obj.Model.State.flir = obj.Model.Services.flir.startAcquisition(obj.Model.State.flir);
                        end
                        if isempty(obj.Model.Ui.FlirLiveTimerHandle) || ~isvalid(obj.Model.Ui.FlirLiveTimerHandle)
                            obj.Model.Ui.FlirLiveTimerHandle = obj.Model.Services.timer.create( ...
                                'Name', 'LaserWritingFlirLiveView', ...
                                'ExecutionMode', 'fixedSpacing', ...
                                'BusyMode', 'drop', ...
                                'Period', obj.Model.Ui.FlirLivePeriodSeconds, ...
                                'TimerFcn', @(~, ~) obj.flirLive('tick'));
                        end
                        if strcmp(obj.Model.Ui.FlirLiveTimerHandle.Running, 'off')
                            start(obj.Model.Ui.FlirLiveTimerHandle);
                        end
                    catch ME
                        obj.Model.Ui.FlirLiveEnabled = false;
                        obj.flirLive('stop-timer');
                        try
                            if obj.isFlirConnected() && isfield(obj.Model.State.flir, 'isAcquiring') && logical(obj.Model.State.flir.isAcquiring)
                                obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
                            end
                        catch
                        end
                        obj.flirLive('update', 'Stopped');
                        rethrow(ME);
                    end
                    obj.flirLive('update');
                    if shouldLog
                        obj.Ports.logMessage('FLIR live view started.');
                    end

                case "stop"
                    shouldLog = nargin >= 3 && logical(varargin{1});
                    wasEnabled = obj.Model.Ui.FlirLiveEnabled;
                    obj.Model.Ui.FlirLiveEnabled = false;
                    obj.Model.Ui.FlirLiveFailureCount = 0;
                    obj.flirLive('stop-timer');
                    try
                        if obj.isFlirConnected() && isfield(obj.Model.State.flir, 'isAcquiring') && ...
                                logical(obj.Model.State.flir.isAcquiring) && ~obj.Model.State.isBusy
                            obj.Model.State.flir = obj.Model.Services.flir.stopAcquisition(obj.Model.State.flir);
                        end
                    catch ME
                        obj.Ports.logMessage(sprintf('FLIR live acquisition stop failed: %s', compactErrorMessage(ME)));
                    end
                    obj.setFlirLiveAxesTitle('Live stopped');
                    obj.flirLive('update');
                    if shouldLog && wasEnabled
                        obj.Ports.logMessage('FLIR live view stopped.');
                    end

                case "pause"
                    statusText = 'Paused';
                    if nargin >= 3
                        statusText = varargin{1};
                    end
                    outputValue = obj.Model.Ui.FlirLiveEnabled;
                    if outputValue
                        obj.flirLive('stop', false);
                        obj.flirLive('update', statusText);
                    end

                case "resume"
                    shouldResume = nargin >= 3 && logical(varargin{1});
                    if shouldResume
                        try
                            if isvalid(obj.Model.Figure) && obj.isFlirConnected() && ~obj.Model.State.isBusy && ~obj.Model.State.isPaused
                                obj.flirLive('start', false);
                                obj.Ports.logMessage('FLIR live view resumed.');
                            end
                        catch ME
                            obj.Ports.logMessage(sprintf('FLIR live view could not resume: %s', compactErrorMessage(ME)));
                            obj.flirLive('update', 'Stopped');
                        end
                    end

                case "tick"
                    if ~obj.Model.Ui.FlirLiveEnabled
                        return;
                    end
                    if obj.Model.Ui.FlirLiveTickInProgress
                        return;
                    end
                    obj.Model.Ui.FlirLiveTickInProgress = true;
                    tickCleanupObj = onCleanup(@() obj.setFlirLiveTickInProgress(false));
                    allowPausedManualMotion = nargin >= 3 && logical(varargin{1});
                    try
                        if ~isvalid(obj.Model.Figure)
                            obj.flirLive('delete');
                            return;
                        end
                        if ~obj.isFlirLiveWindowOpen() || ~obj.hasValidUiControl('FlirLiveAxes')
                            obj.flirLive('stop', false);
                            return;
                        end
                        if ~obj.isFlirConnected()
                            obj.flirLive('stop', false);
                            return;
                        end
                        manualMotionLiveAllowed = allowPausedManualMotion && ...
                            ~obj.Model.State.isBusy && obj.Model.State.isPaused && obj.Model.PausedManualMotionActive;
                        if obj.Model.State.isBusy || obj.Model.State.isPaused || obj.Model.PausedManualMotionActive
                            if ~manualMotionLiveAllowed
                                obj.flirLive('update', 'Paused');
                                return;
                            end
                        end
                        if ~isfield(obj.Model.State.flir, 'isAcquiring') || ~logical(obj.Model.State.flir.isAcquiring)
                            obj.Model.State.flir = obj.Model.Services.flir.startAcquisition(obj.Model.State.flir);
                        end

                        timeoutMs = obj.flirLiveTimeoutMs();
                        [obj.Model.State.flir, frame, info] = obj.Model.Services.flir.grabFrame( ...
                            obj.Model.State.flir, timeoutMs);
                        obj.Model.Ui.FlirLiveFrameCount = obj.Model.Ui.FlirLiveFrameCount + 1;
                        obj.Model.Ui.FlirLiveFailureCount = 0;
                        obj.Model.Ui.FlirLiveLastFrameTic = obj.Model.Services.clock.tic();
                        obj.refreshFlirLiveReadouts(true);
                        obj.showFlirLiveFrame(frame, info);
                        if manualMotionLiveAllowed
                            obj.flirLive('update', sprintf('Live %d', obj.Model.Ui.FlirLiveFrameCount));
                        else
                            obj.flirLive('update');
                        end
                        obj.Model.Services.ui.drawnow('limitrate');
                    catch ME
                        obj.Model.Ui.FlirLiveFailureCount = obj.Model.Ui.FlirLiveFailureCount + 1;
                        obj.setFlirLiveAxesTitle('Live error');
                        obj.flirLive('update', sprintf('Error %d', obj.Model.Ui.FlirLiveFailureCount));
                        if obj.Model.Ui.FlirLiveFailureCount == 1
                            obj.Ports.logMessage(sprintf('FLIR live view error: %s', compactErrorMessage(ME)));
                        end
                        if obj.Model.Ui.FlirLiveFailureCount >= 3
                            obj.flirLive('stop', false);
                            obj.setFlirLiveAxesTitle('Live stopped after errors');
                            obj.Ports.logMessage('FLIR live view stopped after repeated errors.');
                        end
                    end
                    clear tickCleanupObj

                case "stop-timer"
                    try
                        if ~isempty(obj.Model.Ui.FlirLiveTimerHandle) && isvalid(obj.Model.Ui.FlirLiveTimerHandle)
                            stop(obj.Model.Ui.FlirLiveTimerHandle);
                        end
                    catch
                    end

                case "delete"
                    obj.Model.Ui.FlirLiveEnabled = false;
                    obj.Model.Ui.FlirLiveFailureCount = 0;
                    try
                        if ~isempty(obj.Model.Ui.FlirLiveTimerHandle) && isvalid(obj.Model.Ui.FlirLiveTimerHandle)
                            stop(obj.Model.Ui.FlirLiveTimerHandle);
                            delete(obj.Model.Ui.FlirLiveTimerHandle);
                        end
                    catch
                    end
                    obj.Model.Ui.FlirLiveTimerHandle = [];
                    obj.deleteFlirLiveWindow();

                case "close-window"
                    try
                        obj.flirLive('stop', true);
                    catch ME
                        obj.Ports.logMessage(sprintf('FLIR live view stop failed while closing window: %s', compactErrorMessage(ME)));
                    end
                    obj.deleteFlirLiveWindow();

                case "update"
                    if nargin >= 3
                        statusText = varargin{1};
                    elseif obj.Model.Ui.FlirLiveEnabled
                        if obj.Model.State.isBusy || obj.Model.State.isPaused || obj.Model.PausedManualMotionActive
                            statusText = 'Paused';
                        else
                            statusText = sprintf('Live %d', obj.Model.Ui.FlirLiveFrameCount);
                        end
                    elseif obj.isFlirConnected()
                        statusText = 'Stopped';
                    else
                        statusText = 'Disconnected';
                    end
                    obj.updateFlirLiveUi(statusText);
            end

            if nargout > 0
                varargout{1} = outputValue;
            end
        end

        function timeoutMs = flirLiveTimeoutMs(obj)
            timeoutMs = obj.Model.Ui.FlirLiveTimeoutMs;
            if obj.hasValidUiControl('FlirLiveTimeoutField')
                try
                    timeoutMs = positiveInteger(obj.Model.Ui.FlirLiveTimeoutField.Value, 'FLIR live timeout');
                    obj.Model.Ui.FlirLiveTimeoutMs = max(250, min(timeoutMs, 750));
                    obj.Model.Ui.FlirLiveTimeoutField.Value = obj.Model.Ui.FlirLiveTimeoutMs;
                catch
                    obj.Model.Ui.FlirLiveTimeoutField.Value = obj.Model.Ui.FlirLiveTimeoutMs;
                    timeoutMs = obj.Model.Ui.FlirLiveTimeoutMs;
                end
            end
        end

        function setFlirLiveTickInProgress(obj, value)
            obj.Model.Ui.FlirLiveTickInProgress = logical(value);
        end

        function showFlirLiveFrame(obj, frame, info)
            if ~obj.hasValidUiControl('FlirLiveAxes')
                return;
            end
            if ismatrix(frame)
                if obj.flirLiveMarkersEnabled()
                    image(obj.Model.Ui.FlirLiveAxes, obj.flirLiveFrameWithRangeMarkers(frame, info));
                else
                    imagesc(obj.Model.Ui.FlirLiveAxes, frame);
                    colormap(obj.Model.Ui.FlirLiveAxes, gray(256));
                end
            else
                image(obj.Model.Ui.FlirLiveAxes, frame);
            end
            axis(obj.Model.Ui.FlirLiveAxes, 'image');
            obj.Model.Ui.FlirLiveAxes.XTick = [];
            obj.Model.Ui.FlirLiveAxes.YTick = [];
            obj.setFlirLiveAxesTitle(sprintf('Live %s | %d x %d%s %s', ...
                char(datetime('now', 'Format', 'HH:mm:ss')), info.Width, info.Height, ...
                obj.flirFrameOffsetText(info), info.PixelFormat));
        end

        function tf = flirLiveMarkersEnabled(obj)
            tf = obj.hasValidUiControl('FlirLiveMarkerCheckBox') && logical(obj.Model.Ui.FlirLiveMarkerCheckBox.Value);
        end

        function redrawLastFlirLiveFrame(obj)
            if obj.Model.Ui.FlirRoiEditActive
                % Redrawing the image would delete the ROI rectangle being edited.
                return;
            end
            if ~isfield(obj.Model.State, 'flir') || ~isfield(obj.Model.State.flir, 'lastFrame') || isempty(obj.Model.State.flir.lastFrame)
                return;
            end
            if ~isfield(obj.Model.State.flir, 'lastFrameInfo') || isempty(obj.Model.State.flir.lastFrameInfo)
                return;
            end
            obj.showFlirLiveFrame(obj.Model.State.flir.lastFrame, obj.Model.State.flir.lastFrameInfo);
            obj.Model.Services.ui.drawnow('limitrate');
        end

        function rgbFrame = flirLiveFrameWithRangeMarkers(obj, frame, info)
            frameValues = double(frame);
            finitePixels = isfinite(frameValues);
            if any(finitePixels(:))
                frameMin = min(frameValues(finitePixels));
                frameMax = max(frameValues(finitePixels));
            else
                frameMin = 0;
                frameMax = 0;
            end
            frameValues(~finitePixels) = frameMin;

            if frameMax > frameMin
                grayFrame = uint8(round(255 * (frameValues - frameMin) / (frameMax - frameMin)));
            else
                grayFrame = zeros(size(frame), 'uint8');
            end

            rgbFrame = repmat(grayFrame, 1, 1, 3);
            saturationValue = obj.flirLiveSaturationValue(frame, info);
            saturatedPixels = false(size(frame));
            if isfinite(saturationValue)
                saturatedPixels = finitePixels & frameValues >= saturationValue;
            end

            zeroPixels = finitePixels & frameValues == 0;
            if ~any(saturatedPixels(:)) && ~any(zeroPixels(:))
                return;
            end

            redChannel = rgbFrame(:, :, 1);
            greenChannel = rgbFrame(:, :, 2);
            blueChannel = rgbFrame(:, :, 3);
            redChannel(saturatedPixels) = uint8(255);
            greenChannel(saturatedPixels) = uint8(0);
            blueChannel(saturatedPixels) = uint8(0);
            redChannel(zeroPixels) = uint8(0);
            greenChannel(zeroPixels) = uint8(0);
            blueChannel(zeroPixels) = uint8(255);
            rgbFrame(:, :, 1) = redChannel;
            rgbFrame(:, :, 2) = greenChannel;
            rgbFrame(:, :, 3) = blueChannel;
        end

        function saturationValue = flirLiveSaturationValue(~, frame, info)
            saturationValue = NaN;
            pixelFormat = "";
            if nargin >= 3 && isstruct(info) && isfield(info, 'PixelFormat') && ~isempty(info.PixelFormat)
                pixelFormat = string(info.PixelFormat);
            end

            bitDepthToken = regexp(char(pixelFormat), 'Mono(\d+)', 'tokens', 'once', 'ignorecase');
            if ~isempty(bitDepthToken)
                bitDepth = str2double(bitDepthToken{1});
                if isfinite(bitDepth) && bitDepth > 0 && bitDepth <= 52
                    saturationValue = 2 ^ round(bitDepth) - 1;
                    return;
                end
            end

            if isinteger(frame)
                saturationValue = double(intmax(class(frame)));
                return;
            end

            if nargin >= 3 && isstruct(info) && isfield(info, 'BitsPerPixel') && ~isempty(info.BitsPerPixel)
                bitDepth = double(info.BitsPerPixel);
                if isfinite(bitDepth) && bitDepth > 0 && bitDepth <= 52
                    saturationValue = 2 ^ round(bitDepth) - 1;
                end
            end
        end

        function setFlirLiveAxesTitle(obj, titleText)
            if obj.hasValidUiControl('FlirLiveAxes')
                title(obj.Model.Ui.FlirLiveAxes, titleText);
            end
        end

        function updateFlirLiveUi(obj, statusText)
            if obj.hasValidUiControl('OpenFlirLiveWindowButton')
                if obj.Model.Ui.FlirLiveEnabled
                    obj.Model.Ui.OpenFlirLiveWindowButton.Text = 'Live FLIR (Running)';
                else
                    obj.Model.Ui.OpenFlirLiveWindowButton.Text = 'Live FLIR...';
                end
            end

            if ~obj.isFlirLiveWindowOpen()
                return;
            end

            if obj.hasValidUiControl('FlirLiveStatusLabel')
                obj.Model.Ui.FlirLiveStatusLabel.Text = char(statusText);
            end
            if obj.hasValidUiControl('FlirLiveCameraLabel')
                obj.Model.Ui.FlirLiveCameraLabel.Text = obj.selectedFlirCameraLabel();
            end
            if obj.hasValidUiControl('FlirLiveButton')
                if obj.Model.Ui.FlirLiveEnabled
                    obj.Model.Ui.FlirLiveButton.Text = 'Stop Live';
                else
                    obj.Model.Ui.FlirLiveButton.Text = 'Start Live';
                end
            end
            obj.refreshFlirLiveReadouts(false);
            obj.syncFlirRoiInfo();
            obj.syncFlirLiveWindowControlEnableStates();
        end

        function syncFlirLiveWindowControlEnableStates(obj)
            if ~obj.isFlirLiveWindowOpen()
                return;
            end
            canUseFlir = obj.isFlirConnected() && ~obj.Model.State.isBusy && ~obj.Model.State.isPaused && ~obj.Model.PausedManualMotionActive;
            roiEditing = obj.Model.Ui.FlirRoiEditActive;
            obj.setEnableIfValid('FlirLiveButton', canUseFlir && ~roiEditing);
            obj.setEnableIfValid('FlirLiveDrawRoiButton', canUseFlir);
            obj.setEnableIfValid('FlirLiveFullFrameButton', canUseFlir && ~roiEditing);
            obj.setEnableIfValid('FlirLiveApplyRoiButton', canUseFlir && obj.isFlirLiveRoiDrawn());
            obj.setEnableIfValid('FlirLiveCancelRoiButton', roiEditing);
            obj.setEnableIfValid('FlirLiveExposureField', canUseFlir);
            obj.setEnableIfValid('FlirLiveApplyExposureButton', canUseFlir);
            obj.setEnableIfValid('FlirLiveGainField', canUseFlir);
            obj.setEnableIfValid('FlirLiveApplyGainButton', canUseFlir);
            obj.setEnableIfValid('FlirLiveTimeoutField', canUseFlir);
            obj.setEnableIfValid('FlirLivePeriodField', canUseFlir);
        end

        function tf = isFlirLiveWindowOpen(obj)
            tf = obj.hasValidUiControl('FlirLiveFigure');
        end

        function tf = hasValidUiControl(obj, fieldName)
            tf = isfield(obj.Model.Ui, fieldName) && isValidUiHandle(obj.Model.Ui.(fieldName));
        end

        function setEnableIfValid(obj, fieldName, shouldEnable)
            if obj.hasValidUiControl(fieldName)
                setEnable(obj.Model.Ui.(fieldName), shouldEnable);
            end
        end

        function deleteFlirLiveWindow(obj)
            liveFigure = [];
            if isfield(obj.Model.Ui, 'FlirLiveFigure')
                liveFigure = obj.Model.Ui.FlirLiveFigure;
            end
            wasEditingRoi = obj.Model.Ui.FlirRoiEditActive;
            obj.endFlirLiveRoiEdit();
            obj.clearFlirLiveWindowHandles();
            if wasEditingRoi
                obj.syncFlirRoiFieldsFromSelection();
            end
            try
                if isValidUiHandle(liveFigure)
                    liveFigure.CloseRequestFcn = [];
                    delete(liveFigure);
                end
            catch
            end
            obj.updateFlirLiveUi('Stopped');
        end

        function clearFlirLiveWindowHandles(obj)
            obj.Model.Ui.FlirLiveFigure = [];
            obj.Model.Ui.FlirLiveAxes = [];
            obj.Model.Ui.FlirLiveStatusLabel = [];
            obj.Model.Ui.FlirLiveCameraLabel = [];
            obj.Model.Ui.FlirLiveCurrentExposureLabel = [];
            obj.Model.Ui.FlirLiveCurrentGainLabel = [];
            obj.Model.Ui.FlirLiveButton = [];
            obj.Model.Ui.FlirLiveExposureField = [];
            obj.Model.Ui.FlirLiveApplyExposureButton = [];
            obj.Model.Ui.FlirLiveGainField = [];
            obj.Model.Ui.FlirLiveApplyGainButton = [];
            obj.Model.Ui.FlirLiveTimeoutField = [];
            obj.Model.Ui.FlirLivePeriodField = [];
            obj.Model.Ui.FlirLiveMarkerCheckBox = [];
            obj.Model.Ui.FlirLiveRoiLabel = [];
            obj.Model.Ui.FlirLiveDrawRoiButton = [];
            obj.Model.Ui.FlirLiveFullFrameButton = [];
            obj.Model.Ui.FlirLiveApplyRoiButton = [];
            obj.Model.Ui.FlirLiveCancelRoiButton = [];
        end

        function requireFlirConnected(obj)
            if ~obj.isFlirConnected()
                error('FLIR camera is not connected.');
            end
        end

        function tf = isFlirConnected(obj)
            tf = isfield(obj.Model.State, 'flir') && ...
                obj.Model.Services.flir.isConnected(obj.Model.State.flir);
        end

        function syncFlirUi(obj)
            if ~isfield(obj.Model.Ui, 'FlirStatusLabel')
                return;
            end

            if obj.isFlirConnected()
                label = 'Connected';
                if isfield(obj.Model.State.flir, 'selectedDevice') && isstruct(obj.Model.State.flir.selectedDevice) && ...
                        isfield(obj.Model.State.flir.selectedDevice, 'Label')
                    label = ['Connected: ' obj.Model.State.flir.selectedDevice.Label];
                end
                obj.Model.Ui.FlirStatusLabel.Text = label;
            elseif isfield(obj.Model.State, 'flir') && isfield(obj.Model.State.flir, 'devices') && ~isempty(obj.Model.State.flir.devices)
                obj.Model.Ui.FlirStatusLabel.Text = sprintf('%d camera(s) detected', numel(obj.Model.State.flir.devices));
            else
                obj.Model.Ui.FlirStatusLabel.Text = 'Disconnected';
            end
            obj.syncFlirRoiInfo();
            obj.flirLive('update');
        end

        function idx = selectedFlirDeviceIndex(obj)
            idx = [];
            if ~isfield(obj.Model.Ui, 'FlirDeviceDropDown') || isempty(obj.Model.Ui.FlirDeviceDropDown.Items)
                return;
            end
            value = obj.Model.Ui.FlirDeviceDropDown.Value;
            token = regexp(value, '^(\d+):', 'tokens', 'once');
            if isempty(token)
                return;
            end
            idx = str2double(token{1});
            if isnan(idx) || ~isfield(obj.Model.State, 'flir') || ~isfield(obj.Model.State.flir, 'devices') || ...
                    idx < 1 || idx > numel(obj.Model.State.flir.devices)
                idx = [];
            end
        end

        function label = selectedFlirCameraLabel(obj)
            label = 'FLIR camera';
            idx = obj.selectedFlirDeviceIndex();
            if ~isempty(idx) && isfield(obj.Model.State.flir, 'devices') && idx <= numel(obj.Model.State.flir.devices)
                label = obj.Model.State.flir.devices(idx).Label;
            elseif isfield(obj.Model.State, 'flir') && isfield(obj.Model.State.flir, 'selectedDevice') && ...
                    isstruct(obj.Model.State.flir.selectedDevice) && isfield(obj.Model.State.flir.selectedDevice, 'Label')
                label = obj.Model.State.flir.selectedDevice.Label;
            end
        end

        function refreshFlirDeviceDropDown(obj)
            if ~isfield(obj.Model.Ui, 'FlirDeviceDropDown')
                return;
            end
            if ~isfield(obj.Model.State, 'flir') || ~isfield(obj.Model.State.flir, 'devices') || isempty(obj.Model.State.flir.devices)
                obj.Model.Ui.FlirDeviceDropDown.Items = {'No camera detected'};
                obj.Model.Ui.FlirDeviceDropDown.Value = 'No camera detected';
                return;
            end

            labels = {obj.Model.State.flir.devices.Label};
            obj.Model.Ui.FlirDeviceDropDown.Items = labels;
            if ~any(strcmp(obj.Model.Ui.FlirDeviceDropDown.Value, labels))
                obj.Model.Ui.FlirDeviceDropDown.Value = labels{1};
            end
        end

    end
end
