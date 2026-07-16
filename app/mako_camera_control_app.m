function app = mako_camera_control_app(parent, options)
%MAKO_CAMERA_CONTROL_APP Standalone controller for Allied Vision Mako cameras.
%   Requires Image Acquisition Toolbox and a GenTL producer such as Vimba X.
%   With no input, returns the standalone figure. When a parent UI container
%   is supplied, embeds the controls and returns a lifecycle controller.

if nargin < 1
    parent = [];
end
if nargin < 2 || isempty(options)
    options = struct();
end
ownsFigure = isempty(parent);
fig = [];

state = struct();
state.vid = [];
state.src = [];
state.devices = struct([]);
state.formats = {};
state.imageHandle = [];
state.previewInputHandle = [];
state.previewListener = [];
state.lastFrame = [];
state.nativeFrameSize = [];
state.isConnected = false;
state.isPreviewing = false;
state.lastLogMessage = "";
state.rotationDegrees = 0;
state.markers = struct('id', {}, 'x', {}, 'y', {}, 'visible', {}, 'graphics', {});
state.selectedMarkerId = [];
state.markerPlacementMode = "none";
state.showMarkers = true;
state.gentlPathPrepared = false;
state.popoutFigure = [];
state.popoutAxes = [];
state.popoutImageHandle = [];
state.embeddedDisplaySize = [];
state.popoutDisplaySize = [];
% Keep acquisition free-running while presenting only the newest frame at 20 Hz.
state.previewRenderPeriodSeconds = 1 / 20;
state.lastPreviewRenderTic = [];
state.previewRenderInProgress = false;

ui = struct();
ui.MainViewControls = struct();
ui.PopoutViewControls = struct();

buildUi();
logMessage('App opened. Close Vimba X Viewer before connecting if the camera is busy.');
refreshDevices();
if ownsFigure
    app = fig;
else
    app = struct( ...
        'disconnect', @disconnectCamera, ...
        'shutdown', @shutdownController, ...
        'isConnected', @controllerIsConnected, ...
        'captureFrame', @controllerCaptureFrame);
end

    function buildUi()
        if ownsFigure
            fig = uifigure( ...
                'Name', 'Mako Camera Control', ...
                'Position', [120, 80, 1220, 760], ...
                'CloseRequestFcn', @onCloseRequested);
            rootContainer = fig;
        else
            if ~isvalid(parent)
                error('Mako camera parent UI container is invalid.');
            end
            rootContainer = parent;
            fig = ancestor(parent, 'figure');
        end

        mainGrid = uigridlayout(rootContainer, [2, 2], ...
            'ColumnWidth', {330, '1x'}, ...
            'RowHeight', {'1x', 155}, ...
            'Padding', [10, 10, 10, 10], ...
            'ColumnSpacing', 10, ...
            'RowSpacing', 10);

        buildControls(mainGrid);
        buildPreview(mainGrid);
        buildLog(mainGrid);
    end

    function buildControls(parent)
        panel = uipanel(parent, 'Title', 'Camera');
        panel.Layout.Row = 1;
        panel.Layout.Column = 1;

        grid = uigridlayout(panel, [20, 2], ...
            'ColumnWidth', {'1x', '1x'}, ...
            'RowHeight', {22, 32, 22, 32, 32, 14, 32, 32, 14, 28, 32, 32, 14, 28, 32, 14, 28, 32, 14, 32}, ...
            'Padding', [10, 8, 10, 8], ...
            'ColumnSpacing', 8, ...
            'RowSpacing', 6);
        if isprop(grid, 'Scrollable')
            grid.Scrollable = 'on';
        end

        uilabel(grid, 'Text', 'Detected camera');
        ui.RefreshButton = uibutton(grid, 'push', ...
            'Text', 'Refresh', ...
            'ButtonPushedFcn', @onRefresh);
        ui.RefreshButton.Layout.Row = 1;
        ui.RefreshButton.Layout.Column = 2;

        ui.DeviceDropDown = uidropdown(grid, ...
            'Items', {'No camera detected'}, ...
            'ValueChangedFcn', @onDeviceChanged);
        ui.DeviceDropDown.Layout.Row = 2;
        ui.DeviceDropDown.Layout.Column = [1 2];

        uilabel(grid, 'Text', 'Pixel format');
        ui.FormatDropDown = uidropdown(grid, ...
            'Items', {'-'});
        ui.FormatDropDown.Layout.Row = 4;
        ui.FormatDropDown.Layout.Column = [1 2];

        ui.ConnectButton = uibutton(grid, 'push', ...
            'Text', 'Connect', ...
            'ButtonPushedFcn', @onConnect);
        ui.ConnectButton.Layout.Row = 5;
        ui.ConnectButton.Layout.Column = 1;
        ui.DisconnectButton = uibutton(grid, 'push', ...
            'Text', 'Disconnect', ...
            'ButtonPushedFcn', @onDisconnect);
        ui.DisconnectButton.Layout.Row = 5;
        ui.DisconnectButton.Layout.Column = 2;

        ui.StartPreviewButton = uibutton(grid, 'push', ...
            'Text', 'Start Preview', ...
            'ButtonPushedFcn', @onStartPreview);
        ui.StartPreviewButton.Layout.Row = 7;
        ui.StartPreviewButton.Layout.Column = 1;
        ui.StopPreviewButton = uibutton(grid, 'push', ...
            'Text', 'Stop Preview', ...
            'ButtonPushedFcn', @onStopPreview);
        ui.StopPreviewButton.Layout.Row = 7;
        ui.StopPreviewButton.Layout.Column = 2;

        ui.CaptureButton = uibutton(grid, 'push', ...
            'Text', 'Capture', ...
            'ButtonPushedFcn', @onCapture);
        ui.CaptureButton.Layout.Row = 8;
        ui.CaptureButton.Layout.Column = 1;
        ui.SaveButton = uibutton(grid, 'push', ...
            'Text', 'Save Image', ...
            'ButtonPushedFcn', @onSaveImage);
        ui.SaveButton.Layout.Row = 8;
        ui.SaveButton.Layout.Column = 2;

        ui.ExposureAutoCheckBox = uicheckbox(grid, ...
            'Text', 'Exposure auto', ...
            'ValueChangedFcn', @onExposureAutoChanged);
        ui.ExposureAutoCheckBox.Layout.Row = 10;
        ui.ExposureAutoCheckBox.Layout.Column = [1 2];

        uilabel(grid, 'Text', 'Exposure time (us)');
        ui.ExposureEdit = uieditfield(grid, 'numeric', ...
            'Limits', [0 Inf], ...
            'RoundFractionalValues', 'off');
        ui.ExposureEdit.Layout.Row = 11;
        ui.ExposureEdit.Layout.Column = 2;
        ui.ApplyExposureButton = uibutton(grid, 'push', ...
            'Text', 'Apply Exposure', ...
            'ButtonPushedFcn', @onApplyExposure);
        ui.ApplyExposureButton.Layout.Row = 12;
        ui.ApplyExposureButton.Layout.Column = [1 2];

        ui.GainAutoCheckBox = uicheckbox(grid, ...
            'Text', 'Gain auto', ...
            'ValueChangedFcn', @onGainAutoChanged);
        ui.GainAutoCheckBox.Layout.Row = 14;
        ui.GainAutoCheckBox.Layout.Column = [1 2];

        uilabel(grid, 'Text', 'Gain');
        ui.GainEdit = uieditfield(grid, 'numeric', ...
            'RoundFractionalValues', 'off');
        ui.GainEdit.Layout.Row = 15;
        ui.GainEdit.Layout.Column = 2;

        ui.ApplyGainButton = uibutton(grid, 'push', ...
            'Text', 'Apply Gain', ...
            'ButtonPushedFcn', @onApplyGain);
        ui.ApplyGainButton.Layout.Row = 17;
        ui.ApplyGainButton.Layout.Column = [1 2];

        uilabel(grid, 'Text', 'Frame rate (Hz)');
        ui.FrameRateEdit = uieditfield(grid, 'numeric', ...
            'Limits', [0 Inf], ...
            'RoundFractionalValues', 'off');
        ui.FrameRateEdit.Layout.Row = 18;
        ui.FrameRateEdit.Layout.Column = 2;

        ui.ApplyFrameRateButton = uibutton(grid, 'push', ...
            'Text', 'Apply Frame Rate', ...
            'ButtonPushedFcn', @onApplyFrameRate);
        ui.ApplyFrameRateButton.Layout.Row = 20;
        ui.ApplyFrameRateButton.Layout.Column = [1 2];
    end

    function buildPreview(parent)
        rightGrid = uigridlayout(parent, [3, 1], ...
            'RowHeight', {34, 72, '1x'}, ...
            'Padding', [0, 0, 0, 0], ...
            'RowSpacing', 6);
        rightGrid.Layout.Row = 1;
        rightGrid.Layout.Column = 2;

        statusGrid = uigridlayout(rightGrid, [1, 5], ...
            'ColumnWidth', {22, '1x', 'fit', 'fit', 'fit'}, ...
            'Padding', [0, 0, 0, 0], ...
            'ColumnSpacing', 8);
        statusGrid.Layout.Row = 1;

        ui.StatusLamp = uilamp(statusGrid, 'Color', [0.85, 0.2, 0.2]);
        ui.StatusLamp.Layout.Column = 1;
        ui.StatusLabel = uilabel(statusGrid, 'Text', 'Disconnected');
        ui.StatusLabel.Layout.Column = 2;
        ui.ExposureReadoutLabel = uilabel(statusGrid, 'Text', 'Exposure: -');
        ui.ExposureReadoutLabel.Layout.Column = 3;
        ui.GainReadoutLabel = uilabel(statusGrid, 'Text', 'Gain: -');
        ui.GainReadoutLabel.Layout.Column = 4;
        ui.PopOutButton = uibutton(statusGrid, 'push', ...
            'Text', 'Pop Out View', ...
            'ButtonPushedFcn', @onOpenPopout);
        ui.PopOutButton.Layout.Column = 5;

        overlayGrid = uigridlayout(rightGrid, [2, 10], ...
            'ColumnWidth', {86, 110, 72, 72, 70, 65, 70, 'fit', 'fit', '1x'}, ...
            'RowHeight', {32, 32}, ...
            'Padding', [0, 0, 0, 0], ...
            'ColumnSpacing', 5, ...
            'RowSpacing', 4);
        overlayGrid.Layout.Row = 2;

        rotationLabel = uilabel(overlayGrid, 'Text', 'Rotation');
        rotationLabel.Layout.Row = 1;
        rotationLabel.Layout.Column = 1;
        ui.RotationDropDown = uidropdown(overlayGrid, ...
            'Items', {'0 deg', '90 deg CW', '180 deg', '270 deg CW'}, ...
            'ItemsData', [0, 90, 180, 270], ...
            'Value', 0, ...
            'ValueChangedFcn', @onRotationChanged);
        ui.RotationDropDown.Layout.Row = 1;
        ui.RotationDropDown.Layout.Column = 2;

        ui.ZoomInButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Zoom In', ...
            'ButtonPushedFcn', @onZoomIn);
        ui.ZoomInButton.Layout.Row = 1;
        ui.ZoomInButton.Layout.Column = 3;
        ui.ZoomOutButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Zoom Out', ...
            'ButtonPushedFcn', @onZoomOut);
        ui.ZoomOutButton.Layout.Row = 1;
        ui.ZoomOutButton.Layout.Column = 4;
        ui.FitViewButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Fit', ...
            'ButtonPushedFcn', @onFitView);
        ui.FitViewButton.Layout.Row = 1;
        ui.FitViewButton.Layout.Column = 5;

        ui.AddMarkerButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Add Marker', ...
            'ButtonPushedFcn', @onAddMarker);
        ui.AddMarkerButton.Layout.Row = 2;
        ui.AddMarkerButton.Layout.Column = 1;
        ui.MoveMarkerButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Move Selected', ...
            'ButtonPushedFcn', @onMoveMarker);
        ui.MoveMarkerButton.Layout.Row = 2;
        ui.MoveMarkerButton.Layout.Column = 2;

        ui.MarkerDropDown = uidropdown(overlayGrid, ...
            'Items', {'No markers'}, ...
            'Value', 'No markers', ...
            'ValueChangedFcn', @onMarkerSelected);
        ui.MarkerDropDown.Layout.Row = 2;
        ui.MarkerDropDown.Layout.Column = [3 4];
        ui.MarkerVisibleCheckBox = uicheckbox(overlayGrid, ...
            'Text', 'Visible', ...
            'Value', true, ...
            'ValueChangedFcn', @onMarkerVisibleChanged);
        ui.MarkerVisibleCheckBox.Layout.Row = 2;
        ui.MarkerVisibleCheckBox.Layout.Column = 5;
        ui.DeleteMarkerButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Delete', ...
            'ButtonPushedFcn', @onDeleteMarker);
        ui.DeleteMarkerButton.Layout.Row = 2;
        ui.DeleteMarkerButton.Layout.Column = 6;
        ui.ClearMarkersButton = uibutton(overlayGrid, 'push', ...
            'Text', 'Clear All', ...
            'ButtonPushedFcn', @onClearMarkers);
        ui.ClearMarkersButton.Layout.Row = 2;
        ui.ClearMarkersButton.Layout.Column = 7;
        ui.ShowMarkersCheckBox = uicheckbox(overlayGrid, ...
            'Text', 'Show markers', ...
            'Value', true, ...
            'ValueChangedFcn', @onShowMarkersChanged);
        ui.ShowMarkersCheckBox.Layout.Row = 2;
        ui.ShowMarkersCheckBox.Layout.Column = [8 9];

        ui.MarkerInstructionLabel = uilabel(overlayGrid, ...
            'Text', 'Add or move, then click the image', ...
            'HorizontalAlignment', 'right');
        ui.MarkerInstructionLabel.Layout.Row = 1;
        ui.MarkerInstructionLabel.Layout.Column = [6 10];

        ui.MainViewControls = collectMainViewControls();

        ui.Axes = uiaxes(rightGrid);
        ui.Axes.Layout.Row = 3;
        title(ui.Axes, 'Camera Preview');
        axis(ui.Axes, 'image');
        ui.Axes.XTick = [];
        ui.Axes.YTick = [];
        ui.Axes.Box = 'on';
        ui.Axes.YDir = 'reverse';
        ui.Axes.NextPlot = 'add';
        updateMarkerControls();
    end

    function controls = collectMainViewControls()
        controls = struct( ...
            'RotationDropDown', ui.RotationDropDown, ...
            'ZoomInButton', ui.ZoomInButton, ...
            'ZoomOutButton', ui.ZoomOutButton, ...
            'FitViewButton', ui.FitViewButton, ...
            'AddMarkerButton', ui.AddMarkerButton, ...
            'MoveMarkerButton', ui.MoveMarkerButton, ...
            'MarkerDropDown', ui.MarkerDropDown, ...
            'MarkerVisibleCheckBox', ui.MarkerVisibleCheckBox, ...
            'DeleteMarkerButton', ui.DeleteMarkerButton, ...
            'ClearMarkersButton', ui.ClearMarkersButton, ...
            'ShowMarkersCheckBox', ui.ShowMarkersCheckBox, ...
            'MarkerInstructionLabel', ui.MarkerInstructionLabel);
    end

    function controls = buildPopoutViewControls(parent)
        toolbarGrid = uigridlayout(parent, [2, 10], ...
            'ColumnWidth', {86, 110, 72, 72, 70, 65, 70, 'fit', 'fit', '1x'}, ...
            'RowHeight', {32, 32}, ...
            'Padding', [0, 0, 0, 0], ...
            'ColumnSpacing', 5, ...
            'RowSpacing', 4);
        toolbarGrid.Layout.Row = 1;

        rotationLabel = uilabel(toolbarGrid, 'Text', 'Rotation');
        rotationLabel.Layout.Row = 1;
        rotationLabel.Layout.Column = 1;
        controls.RotationDropDown = uidropdown(toolbarGrid, ...
            'Items', {'0 deg', '90 deg CW', '180 deg', '270 deg CW'}, ...
            'ItemsData', [0, 90, 180, 270], ...
            'Value', state.rotationDegrees, ...
            'ValueChangedFcn', @onRotationChanged);
        controls.RotationDropDown.Layout.Row = 1;
        controls.RotationDropDown.Layout.Column = 2;

        controls.ZoomInButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Zoom In', ...
            'ButtonPushedFcn', @onZoomIn);
        controls.ZoomInButton.Layout.Row = 1;
        controls.ZoomInButton.Layout.Column = 3;
        controls.ZoomOutButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Zoom Out', ...
            'ButtonPushedFcn', @onZoomOut);
        controls.ZoomOutButton.Layout.Row = 1;
        controls.ZoomOutButton.Layout.Column = 4;
        controls.FitViewButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Fit', ...
            'ButtonPushedFcn', @onFitView);
        controls.FitViewButton.Layout.Row = 1;
        controls.FitViewButton.Layout.Column = 5;

        controls.AddMarkerButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Add Marker', ...
            'ButtonPushedFcn', @onAddMarker);
        controls.AddMarkerButton.Layout.Row = 2;
        controls.AddMarkerButton.Layout.Column = 1;
        controls.MoveMarkerButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Move Selected', ...
            'ButtonPushedFcn', @onMoveMarker);
        controls.MoveMarkerButton.Layout.Row = 2;
        controls.MoveMarkerButton.Layout.Column = 2;

        controls.MarkerDropDown = uidropdown(toolbarGrid, ...
            'Items', {'No markers'}, ...
            'Value', 'No markers', ...
            'ValueChangedFcn', @onMarkerSelected);
        controls.MarkerDropDown.Layout.Row = 2;
        controls.MarkerDropDown.Layout.Column = [3 4];
        controls.MarkerVisibleCheckBox = uicheckbox(toolbarGrid, ...
            'Text', 'Visible', ...
            'Value', true, ...
            'ValueChangedFcn', @onMarkerVisibleChanged);
        controls.MarkerVisibleCheckBox.Layout.Row = 2;
        controls.MarkerVisibleCheckBox.Layout.Column = 5;
        controls.DeleteMarkerButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Delete', ...
            'ButtonPushedFcn', @onDeleteMarker);
        controls.DeleteMarkerButton.Layout.Row = 2;
        controls.DeleteMarkerButton.Layout.Column = 6;
        controls.ClearMarkersButton = uibutton(toolbarGrid, 'push', ...
            'Text', 'Clear All', ...
            'ButtonPushedFcn', @onClearMarkers);
        controls.ClearMarkersButton.Layout.Row = 2;
        controls.ClearMarkersButton.Layout.Column = 7;
        controls.ShowMarkersCheckBox = uicheckbox(toolbarGrid, ...
            'Text', 'Show markers', ...
            'Value', state.showMarkers, ...
            'ValueChangedFcn', @onShowMarkersChanged);
        controls.ShowMarkersCheckBox.Layout.Row = 2;
        controls.ShowMarkersCheckBox.Layout.Column = [8 9];

        controls.MarkerInstructionLabel = uilabel(toolbarGrid, ...
            'Text', 'Add or move, then click the image', ...
            'HorizontalAlignment', 'right');
        controls.MarkerInstructionLabel.Layout.Row = 1;
        controls.MarkerInstructionLabel.Layout.Column = [6 10];
    end

    function buildLog(parent)
        ui.LogTextArea = uitextarea(parent, ...
            'Editable', 'off', ...
            'Value', {''});
        ui.LogTextArea.Layout.Row = 2;
        ui.LogTextArea.Layout.Column = [1 2];
    end

    function onRefresh(~, ~)
        refreshDevices();
    end

    function refreshDevices()
        if state.isConnected
            logMessage('Disconnect before refreshing the camera list.');
            return
        end

        if exist('imaqhwinfo', 'file') ~= 2
            setStatus(false, 'Image Acquisition Toolbox not found');
            logMessage('Image Acquisition Toolbox is required for GenTL camera control.');
            return
        end

        try
            prepareGentlProducerPath();
            refreshImageAcquisitionCache();
            hw = imaqhwinfo;
            if ~any(strcmpi(hw.InstalledAdaptors, 'gentl'))
                refreshImageAcquisitionCache();
                hw = imaqhwinfo;
            end

            if ~any(strcmpi(hw.InstalledAdaptors, 'gentl'))
                setStatus(false, 'GenTL adaptor not available');
                logGentlInstallHelp();
                return
            end

            info = imaqhwinfo('gentl');
            allDevices = info.DeviceInfo;
            isMako = arrayfun(@(device) contains( ...
                string(getStructField(device, 'DeviceName', '')), ...
                'Mako', 'IgnoreCase', true), allDevices);
            state.devices = allDevices(isMako);
            if isempty(state.devices)
                ui.DeviceDropDown.Items = {'No camera detected'};
                ui.DeviceDropDown.Value = 'No camera detected';
                ui.FormatDropDown.Items = {'-'};
                ui.FormatDropDown.Value = '-';
                setStatus(false, 'No camera detected');
                logMessage('No Allied Vision Mako camera detected. Check USB cable, Vimba X installation, and close Vimba X Viewer.');
                return
            end

            labels = makeDeviceLabels(state.devices);
            ui.DeviceDropDown.Items = labels;
            ui.DeviceDropDown.Value = labels{1};
            logMessage(sprintf('Detected %d GenTL camera(s).', numel(state.devices)));
            updateFormatsForSelectedDevice();
            setStatus(false, 'Camera detected');
        catch ME
            setStatus(false, 'Refresh failed');
            logMessage(['Refresh failed: ' ME.message]);
        end
        updateControlState();
    end

    function labels = makeDeviceLabels(devices)
        labels = cell(1, numel(devices));
        for k = 1:numel(devices)
            name = getStructField(devices(k), 'DeviceName', sprintf('Camera %d', k));
            defaultFormat = getStructField(devices(k), 'DefaultFormat', '-');
            deviceId = getStructField(devices(k), 'DeviceID', k);
            labels{k} = sprintf('%d: %s [%s]', deviceId, name, defaultFormat);
        end
    end

    function value = getStructField(s, fieldName, fallback)
        if isfield(s, fieldName) && ~isempty(s.(fieldName))
            value = s.(fieldName);
        else
            value = fallback;
        end
    end

    function onDeviceChanged(~, ~)
        updateFormatsForSelectedDevice();
    end

    function updateFormatsForSelectedDevice()
        idx = selectedDeviceIndex();
        if isempty(idx)
            state.formats = {};
            ui.FormatDropDown.Items = {'-'};
            ui.FormatDropDown.Value = '-';
            return
        end

        try
            devInfo = imaqhwinfo('gentl', idx);
            state.formats = devInfo.SupportedFormats;
            if isempty(state.formats)
                state.formats = {'Mono8'};
            end
            ui.FormatDropDown.Items = state.formats;
            ui.FormatDropDown.Value = pickPreferredFormat(state.formats);
            logMessage(sprintf('Camera %d formats loaded. Selected %s.', idx, ui.FormatDropDown.Value));
        catch ME
            state.formats = {'Mono8'};
            ui.FormatDropDown.Items = state.formats;
            ui.FormatDropDown.Value = state.formats{1};
            logMessage(['Could not query formats; using Mono8 fallback. ' ME.message]);
        end
    end

    function idx = selectedDeviceIndex()
        idx = [];
        if isempty(state.devices) || isempty(ui.DeviceDropDown.Items)
            return
        end
        value = ui.DeviceDropDown.Value;
        token = regexp(value, '^(\d+):', 'tokens', 'once');
        if isempty(token)
            return
        end
        idx = str2double(token{1});
        deviceIds = arrayfun(@(device) double(getStructField(device, 'DeviceID', NaN)), ...
            state.devices);
        if isnan(idx) || idx < 1 || ~any(deviceIds == idx)
            idx = [];
        end
    end

    function fmt = pickPreferredFormat(formats)
        preferred = {'Mono8', 'Mono12', 'Mono16', 'BayerRG8', 'BayerGB8', 'RGB8'};
        fmt = formats{1};
        for k = 1:numel(preferred)
            matchIdx = find(strcmpi(formats, preferred{k}), 1);
            if ~isempty(matchIdx)
                fmt = formats{matchIdx};
                return
            end
        end
    end

    function onConnect(~, ~)
        if state.isConnected
            return
        end

        idx = selectedDeviceIndex();
        if isempty(idx)
            logMessage('No camera selected.');
            return
        end

        fmt = ui.FormatDropDown.Value;
        try
            setStatus(false, 'Connecting...');
            drawnow limitrate
            state.vid = videoinput('gentl', idx, fmt);
            state.src = getselectedsource(state.vid);
            state.isConnected = true;

            setInitialAcquisitionMode();
            refreshCameraControls();
            setStatus(true, 'Connected');
            logMessage(sprintf('Connected to camera %d using %s.', idx, fmt));
        catch ME
            cleanupVideo();
            setStatus(false, 'Connection failed');
            logMessage(['Connection failed: ' ME.message]);
        end
        updateControlState();
        notifyConnectionStateChanged();
    end

    function setInitialAcquisitionMode()
        if isempty(state.vid)
            return
        end

        if hasSourceProperty('AcquisitionMode')
            safeSetSourceProperty('AcquisitionMode', 'Continuous');
        end
    end

    function onDisconnect(~, ~)
        disconnectCamera();
    end

    function disconnectCamera()
        stopPreviewIfNeeded();
        cleanupVideo();
        onClosePopout(false);
        state.lastFrame = [];
        state.nativeFrameSize = [];
        cla(ui.Axes);
        resetMarkerGraphics();
        title(ui.Axes, 'Camera Preview');
        axis(ui.Axes, 'image');
        ui.Axes.XTick = [];
        ui.Axes.YTick = [];
        ui.Axes.YDir = 'reverse';
        ui.Axes.NextPlot = 'add';
        cancelMarkerPlacement();
        setStatus(false, 'Disconnected');
        logMessage('Disconnected.');
        updateControlState();
        notifyConnectionStateChanged();
    end

    function cleanupVideo()
        if ~isempty(state.vid)
            try
                if isvalid(state.vid) && isrunning(state.vid)
                    stop(state.vid);
                end
            catch
            end
            try
                delete(state.vid);
            catch
            end
        end
        state.vid = [];
        state.src = [];
        state.isConnected = false;
        state.isPreviewing = false;
        resetPreviewRenderThrottle();
        deletePreviewListener();
        state.previewInputHandle = [];
        state.imageHandle = [];
        state.embeddedDisplaySize = [];
        state.popoutDisplaySize = [];
    end

    function onStartPreview(~, ~)
        if ~state.isConnected
            logMessage('Connect to the camera first.');
            return
        end

        try
            if isempty(state.previewInputHandle) || ~isvalid(state.previewInputHandle) || ...
                    isempty(state.imageHandle) || ~isvalid(state.imageHandle)
                createPreviewImageHandles();
            end

            resetPreviewRenderThrottle();
            preview(state.vid, state.previewInputHandle);
            state.isPreviewing = true;
            setStatus(true, 'Previewing');
            logMessage('Preview started.');
        catch ME
            state.isPreviewing = false;
            setStatus(true, 'Connected');
            logMessage(['Preview failed: ' ME.message]);
        end
        updateControlState();
    end

    function prepareGentlProducerPath()
        if state.gentlPathPrepared
            return
        end
        state.gentlPathPrepared = true;

        rawPath = string(getenv('GENICAM_GENTL64_PATH'));
        if strlength(rawPath) == 0
            return
        end
        pathEntries = string(split(rawPath, pathsep));
        legacyVimbaUsb = contains(pathEntries, 'Vimba_6.0', 'IgnoreCase', true) & ...
            contains(pathEntries, 'VimbaUSBTL', 'IgnoreCase', true);
        spinnakerProducer = contains(pathEntries, 'Spinnaker', 'IgnoreCase', true);
        excludedProducers = legacyVimbaUsb | spinnakerProducer;
        if ~any(excludedProducers)
            return
        end

        pathEntries = pathEntries(~excludedProducers & strlength(pathEntries) > 0);
        setenv('GENICAM_GENTL64_PATH', strjoin(pathEntries, pathsep));
        if any(spinnakerProducer)
            logMessage('Mako GenTL discovery isolated from the FLIR Spinnaker producer.');
        elseif any(legacyVimbaUsb)
            logMessage('Using Vimba X USB producer; ignored duplicate legacy Vimba 6.0 USB producer.');
        end
    end

    function createPreviewImageHandles()
        deletePreviewListener();
        deleteGraphicsHandle(state.previewInputHandle);
        deleteGraphicsHandle(state.imageHandle);

        resolution = state.vid.VideoResolution;
        height = resolution(2);
        width = resolution(1);
        bands = state.vid.NumberOfBands;
        if bands == 1
            initialFrame = zeros(height, width, 'uint8');
        else
            initialFrame = zeros(height, width, bands, 'uint8');
        end
        state.nativeFrameSize = [height, width];

        displayFrame = rotateFrameForDisplay(initialFrame);
        state.imageHandle = image(ui.Axes, ...
            'CData', displayFrame, ...
            'CDataMapping', 'scaled', ...
            'ButtonDownFcn', @onImageClicked, ...
            'PickableParts', 'all', ...
            'HitTest', 'on');
        state.previewInputHandle = image(ui.Axes, ...
            'CData', initialFrame, ...
            'Visible', 'off', ...
            'PickableParts', 'none', ...
            'HitTest', 'off');
        state.previewListener = addlistener(state.previewInputHandle, ...
            'CData', 'PostSet', @(~, ~) onPreviewFrameChanged());
        displaySize = size(displayFrame);
        state.embeddedDisplaySize = displaySize(1:2);
        configureAxesForFrame(displayFrame, true);
        if ismatrix(displayFrame)
            colormap(ui.Axes, gray(256));
            ui.Axes.CLim = [0, grayscaleDisplayMaximum()];
        end
        redrawMarkers();
    end

    function onPreviewFrameChanged()
        try
            if ~previewRenderIsDue()
                return
            end
            if isempty(state.previewInputHandle) || ~isvalid(state.previewInputHandle)
                return
            end
            frame = state.previewInputHandle.CData;
            if isempty(frame)
                return
            end
            state.previewRenderInProgress = true;
            state.lastPreviewRenderTic = tic;
            renderFrame(frame, 'Live preview');
            finishPreviewRender();
        catch ME
            finishPreviewRender();
            if state.isPreviewing
                setStatus(true, 'Preview display error');
                logMessage(['Preview display update failed: ' ME.message]);
            end
        end
    end

    function tf = previewRenderIsDue()
        % Gate before reading, rotating, or uploading the full image array.
        tf = ~state.previewRenderInProgress && ...
            (isempty(state.lastPreviewRenderTic) || ...
            toc(state.lastPreviewRenderTic) >= state.previewRenderPeriodSeconds);
    end

    function finishPreviewRender()
        state.previewRenderInProgress = false;
    end

    function resetPreviewRenderThrottle()
        state.lastPreviewRenderTic = [];
        state.previewRenderInProgress = false;
    end

    function onStopPreview(~, ~)
        stopPreviewIfNeeded();
        if state.isConnected
            setStatus(true, 'Connected');
        end
        updateControlState();
    end

    function stopPreviewIfNeeded()
        if isempty(state.vid)
            return
        end

        try
            if state.isPreviewing
                stoppreview(state.vid);
                logMessage('Preview stopped.');
            end
        catch ME
            logMessage(['Could not stop preview cleanly: ' ME.message]);
        end
        state.isPreviewing = false;
        resetPreviewRenderThrottle();
    end

    function onCapture(~, ~)
        if ~state.isConnected
            logMessage('Connect to the camera first.');
            return
        end

        try
            frame = getsnapshot(state.vid);
            state.lastFrame = frame;
            showFrame(frame);
            refreshReadouts();
            logMessage(sprintf('Captured image: %s.', sizeText(frame)));
        catch ME
            logMessage(['Capture failed: ' ME.message]);
        end
    end

    function showFrame(frame)
        if isempty(frame)
            return
        end
        renderFrame(frame, sprintf('Captured %s', char(datetime('now', 'Format', 'HH:mm:ss'))));
    end

    function renderFrame(frame, titleText, forceConfigure)
        if nargin < 3
            forceConfigure = false;
        end
        frameSize = size(frame);
        nativeSize = frameSize(1:2);
        sizeChanged = ~isequal(state.nativeFrameSize, nativeSize);
        state.nativeFrameSize = nativeSize;
        displayFrame = rotateFrameForDisplay(frame);

        % The embedded image intentionally freezes while the pop-out is active,
        % except when a display setting changes and both views must stay aligned.
        if isPopoutOpen()
            displayConfigurationChanged = updatePopoutFrame(displayFrame, forceConfigure);
            if forceConfigure
                embeddedChanged = updateEmbeddedFrame(displayFrame, titleText, true);
                displayConfigurationChanged = displayConfigurationChanged || embeddedChanged;
            end
        else
            displayConfigurationChanged = updateEmbeddedFrame(displayFrame, titleText, forceConfigure);
        end
        if sizeChanged || displayConfigurationChanged
            redrawMarkers();
        end
        drawnow nocallbacks
    end

    function configurationChanged = updateEmbeddedFrame(displayFrame, titleText, forceConfigure)
        createdImage = isempty(state.imageHandle) || ~isvalid(state.imageHandle);
        if createdImage
            state.imageHandle = image(ui.Axes, ...
                'CData', displayFrame, ...
                'CDataMapping', 'scaled', ...
                'ButtonDownFcn', @onImageClicked, ...
                'PickableParts', 'all', ...
                'HitTest', 'on');
        else
            state.imageHandle.CData = displayFrame;
        end

        displaySize = size(displayFrame);
        configurationChanged = createdImage || forceConfigure || ...
            ~isequal(state.embeddedDisplaySize, displaySize(1:2));
        state.embeddedDisplaySize = displaySize(1:2);
        if configurationChanged
            configureAxesForFrame(displayFrame, true);
            if ismatrix(displayFrame)
                colormap(ui.Axes, gray(256));
                ui.Axes.CLim = [0, grayscaleDisplayMaximum()];
            end
        end
        if strlength(string(titleText)) > 0 && string(ui.Axes.Title.String) ~= string(titleText)
            title(ui.Axes, titleText);
        end
    end

    function configureAxesForFrame(frame, resetView)
        displaySize = size(frame);
        displayHeight = displaySize(1);
        displayWidth = displaySize(2);
        if ~isempty(state.imageHandle) && isvalid(state.imageHandle)
            state.imageHandle.XData = [1, displayWidth];
            state.imageHandle.YData = [1, displayHeight];
        end
        if resetView
            ui.Axes.XLim = [0.5, displayWidth + 0.5];
            ui.Axes.YLim = [0.5, displayHeight + 0.5];
        end
        ui.Axes.XTick = [];
        ui.Axes.YTick = [];
        ui.Axes.YDir = 'reverse';
        ui.Axes.DataAspectRatio = [1, 1, 1];
        ui.Axes.NextPlot = 'add';
    end

    function maximum = grayscaleDisplayMaximum()
        maximum = 255;
        try
            format = string(ui.FormatDropDown.Value);
            if contains(format, '10', 'IgnoreCase', true)
                maximum = 1023;
            elseif contains(format, '12', 'IgnoreCase', true)
                maximum = 4095;
            elseif contains(format, '16', 'IgnoreCase', true)
                maximum = 65535;
            end
        catch
        end
    end

    function frame = rotateFrameForDisplay(frame)
        switch state.rotationDegrees
            case 90
                frame = rot90(frame, -1);
            case 180
                frame = rot90(frame, 2);
            case 270
                frame = rot90(frame, 1);
        end
    end

    function onRotationChanged(source, ~)
        state.rotationDegrees = double(source.Value);
        syncRotationControls();
        renderCurrentFrame(true);
        fitAllViewsToFrame();
        logMessage(sprintf('Display rotation set to %d degrees clockwise.', state.rotationDegrees));
    end

    function onZoomIn(source, ~)
        zoomView(0.7, viewAxesForControl(source));
    end

    function onZoomOut(source, ~)
        zoomView(1 / 0.7, viewAxesForControl(source));
    end

    function onFitView(source, ~)
        fitViewToFrame(viewAxesForControl(source));
    end

    function zoomView(scale, axesHandle)
        if isempty(state.nativeFrameSize) || isempty(axesHandle) || ~isvalid(axesHandle)
            return
        end
        [displayHeight, displayWidth] = displayedFrameDimensions();
        xLimits = axesHandle.XLim;
        yLimits = axesHandle.YLim;
        xCenter = mean(xLimits);
        yCenter = mean(yLimits);
        xSpan = min(max(diff(xLimits) * scale, 8), displayWidth);
        ySpan = min(max(diff(yLimits) * scale, 8), displayHeight);
        axesHandle.XLim = boundedViewLimits(xCenter, xSpan, displayWidth);
        axesHandle.YLim = boundedViewLimits(yCenter, ySpan, displayHeight);
    end

    function limits = boundedViewLimits(center, span, fullSize)
        lowerBound = 0.5;
        upperBound = fullSize + 0.5;
        if span >= fullSize
            limits = [lowerBound, upperBound];
            return
        end
        lower = center - span / 2;
        upper = center + span / 2;
        if lower < lowerBound
            upper = upper + (lowerBound - lower);
            lower = lowerBound;
        elseif upper > upperBound
            lower = lower - (upper - upperBound);
            upper = upperBound;
        end
        limits = [lower, upper];
    end

    function fitViewToFrame(axesHandle)
        if isempty(state.nativeFrameSize) || isempty(axesHandle) || ~isvalid(axesHandle)
            return
        end
        [displayHeight, displayWidth] = displayedFrameDimensions();
        axesHandle.XLim = [0.5, displayWidth + 0.5];
        axesHandle.YLim = [0.5, displayHeight + 0.5];
    end

    function fitAllViewsToFrame()
        fitViewToFrame(ui.Axes);
        if isPopoutOpen()
            fitViewToFrame(state.popoutAxes);
        end
    end

    function axesHandle = viewAxesForControl(source)
        axesHandle = ui.Axes;
        if ~isPopoutOpen()
            return
        end
        try
            sourceFigure = ancestor(source, 'figure');
            if isequal(sourceFigure, state.popoutFigure)
                axesHandle = state.popoutAxes;
            end
        catch
        end
    end

    function onOpenPopout(~, ~)
        if isPopoutOpen()
            try
                figure(state.popoutFigure);
            catch
                state.popoutFigure.Visible = 'on';
            end
            return
        end
        frame = currentRawFrame();
        if isempty(frame)
            logMessage('Start preview or capture a frame before opening the pop-out view.');
            return
        end

        position = [180, 120, 980, 720];
        try
            ownerPosition = fig.Position;
            position(1:2) = ownerPosition(1:2) + [70, 50];
        catch
        end
        state.popoutFigure = uifigure( ...
            'Name', 'Mako Live Monitor', ...
            'Position', position, ...
            'CloseRequestFcn', @onClosePopout);
        popoutGrid = uigridlayout(state.popoutFigure, [2, 1], ...
            'RowHeight', {72, '1x'}, ...
            'Padding', [8, 8, 8, 8], ...
            'RowSpacing', 6);
        ui.PopoutViewControls = buildPopoutViewControls(popoutGrid);
        state.popoutAxes = uiaxes(popoutGrid);
        state.popoutAxes.Layout.Row = 2;
        state.popoutAxes.XTick = [];
        state.popoutAxes.YTick = [];
        state.popoutAxes.YDir = 'reverse';
        state.popoutAxes.DataAspectRatio = [1, 1, 1];
        state.popoutAxes.NextPlot = 'add';
        title(state.popoutAxes, 'Mako live monitor');
        updatePopoutFrame(rotateFrameForDisplay(frame), true);
        redrawMarkers();
        syncRotationControls();
        syncViewControlState();
        updateMarkerControls();
        syncMarkerPlacementControls();
        state.lastPreviewRenderTic = tic;
        logMessage('Mako pop-out live monitor opened.');
    end

    function frame = currentRawFrame()
        frame = [];
        if state.isPreviewing && ~isempty(state.previewInputHandle) && isvalid(state.previewInputHandle)
            frame = state.previewInputHandle.CData;
        elseif ~isempty(state.lastFrame)
            frame = state.lastFrame;
        end
    end

    function configurationChanged = updatePopoutFrame(displayFrame, forceConfigure)
        if nargin < 2
            forceConfigure = false;
        end
        configurationChanged = false;
        if ~isPopoutOpen() || isempty(displayFrame)
            return
        end
        displaySize = size(displayFrame);
        displayHeight = displaySize(1);
        displayWidth = displaySize(2);
        createdImage = isempty(state.popoutImageHandle) || ~isvalid(state.popoutImageHandle);
        if createdImage
            state.popoutImageHandle = image(state.popoutAxes, ...
                'CData', displayFrame, ...
                'CDataMapping', 'scaled', ...
                'ButtonDownFcn', @onImageClicked, ...
                'PickableParts', 'all', ...
                'HitTest', 'on');
        else
            state.popoutImageHandle.CData = displayFrame;
        end

        configurationChanged = createdImage || forceConfigure || ...
            ~isequal(state.popoutDisplaySize, displaySize(1:2));
        state.popoutDisplaySize = displaySize(1:2);
        if configurationChanged
            state.popoutImageHandle.XData = [1, displayWidth];
            state.popoutImageHandle.YData = [1, displayHeight];
            state.popoutAxes.XLim = [0.5, displayWidth + 0.5];
            state.popoutAxes.YLim = [0.5, displayHeight + 0.5];
            state.popoutAxes.YDir = 'reverse';
            state.popoutAxes.DataAspectRatio = [1, 1, 1];
            if ismatrix(displayFrame)
                colormap(state.popoutAxes, gray(256));
                state.popoutAxes.CLim = [0, grayscaleDisplayMaximum()];
            end
        end
    end

    function tf = isPopoutOpen()
        tf = ~isempty(state.popoutFigure) && isvalid(state.popoutFigure) && ...
            ~isempty(state.popoutAxes) && isvalid(state.popoutAxes);
    end

    function onClosePopout(varargin)
        resumeEmbeddedView = true;
        if isscalar(varargin) && islogical(varargin{1})
            resumeEmbeddedView = varargin{1};
        end
        try
            if ~isempty(state.popoutFigure) && isvalid(state.popoutFigure)
                delete(state.popoutFigure);
            end
        catch
        end
        state.popoutFigure = [];
        state.popoutAxes = [];
        state.popoutImageHandle = [];
        state.popoutDisplaySize = [];
        ui.PopoutViewControls = struct();
        if resumeEmbeddedView
            renderCurrentFrame(true);
            if state.isPreviewing
                state.lastPreviewRenderTic = tic;
            end
        end
    end

    function renderCurrentFrame(forceConfigure)
        if nargin < 1
            forceConfigure = false;
        end
        frame = [];
        if state.isPreviewing && ~isempty(state.previewInputHandle) && isvalid(state.previewInputHandle)
            frame = state.previewInputHandle.CData;
        elseif ~isempty(state.lastFrame)
            frame = state.lastFrame;
        end
        if ~isempty(frame)
            renderFrame(frame, ui.Axes.Title.String, forceConfigure);
        end
    end

    function onAddMarker(~, ~)
        armMarkerPlacement("add");
    end

    function onMoveMarker(~, ~)
        if isempty(selectedMarkerIndex())
            logMessage('Select a marker before moving it.');
            return
        end
        armMarkerPlacement("move");
    end

    function armMarkerPlacement(mode)
        if isempty(state.nativeFrameSize)
            logMessage('Start preview or capture a frame before placing markers.');
            return
        end
        if state.markerPlacementMode == mode
            cancelMarkerPlacement();
            return
        end
        state.markerPlacementMode = mode;
        syncMarkerPlacementControls();
    end

    function cancelMarkerPlacement()
        state.markerPlacementMode = "none";
        syncMarkerPlacementControls();
    end

    function syncMarkerPlacementControls()
        addText = 'Add Marker';
        moveText = 'Move Selected';
        instructionText = 'Add or move, then click the image';
        if state.markerPlacementMode == "add"
            addText = 'Cancel Add';
            instructionText = 'Click image to add marker';
        elseif state.markerPlacementMode == "move"
            moveText = 'Cancel Move';
            instructionText = 'Click image to move selected marker';
        end
        controlSets = viewControlSets();
        for controlSetIndex = 1:numel(controlSets)
            controls = controlSets{controlSetIndex};
            controls.AddMarkerButton.Text = addText;
            controls.MoveMarkerButton.Text = moveText;
            controls.MarkerInstructionLabel.Text = instructionText;
        end
    end

    function onImageClicked(source, event)
        if state.markerPlacementMode == "none"
            return
        end
        try
            displayPoint = double(event.IntersectionPoint(1:2));
        catch
            clickedAxes = source.Parent;
            currentPoint = clickedAxes.CurrentPoint;
            displayPoint = double(currentPoint(1, 1:2));
        end
        [displayHeight, displayWidth] = displayedFrameDimensions();
        if displayPoint(1) < 0.5 || displayPoint(1) > displayWidth + 0.5 || ...
                displayPoint(2) < 0.5 || displayPoint(2) > displayHeight + 0.5
            return
        end
        [nativeX, nativeY] = displayToNativePoint(displayPoint(1), displayPoint(2));

        if state.markerPlacementMode == "add"
            addMarker(nativeX, nativeY);
        else
            moveSelectedMarker(nativeX, nativeY);
        end
        cancelMarkerPlacement();
        redrawMarkers();
        updateMarkerControls();
    end

    function addMarker(nativeX, nativeY)
        markerId = nextAvailableMarkerId();
        marker = struct( ...
            'id', markerId, ...
            'x', nativeX, ...
            'y', nativeY, ...
            'visible', true, ...
            'graphics', gobjects(0));
        state.markers(end + 1) = marker;
        state.selectedMarkerId = markerId;
        logMessage(sprintf('Marker %d added at native pixel (%.1f, %.1f).', ...
            markerId, nativeX, nativeY));
    end

    function markerId = nextAvailableMarkerId()
        markerId = 1;
        if isempty(state.markers)
            return
        end
        usedIds = [state.markers.id];
        while any(usedIds == markerId)
            markerId = markerId + 1;
        end
    end

    function moveSelectedMarker(nativeX, nativeY)
        idx = selectedMarkerIndex();
        if isempty(idx)
            return
        end
        state.markers(idx).x = nativeX;
        state.markers(idx).y = nativeY;
        logMessage(sprintf('Marker %d moved to native pixel (%.1f, %.1f).', ...
            state.markers(idx).id, nativeX, nativeY));
    end

    function onMarkerSelected(source, ~)
        value = string(source.Value);
        token = regexp(value, '^Marker\s+(\d+)', 'tokens', 'once');
        if isempty(token)
            state.selectedMarkerId = [];
        else
            state.selectedMarkerId = str2double(token{1});
        end
        updateMarkerControls();
        redrawMarkers();
    end

    function selectMarker(markerId)
        state.selectedMarkerId = markerId;
        updateMarkerControls();
        redrawMarkers();
    end

    function onMarkerVisibleChanged(source, ~)
        idx = selectedMarkerIndex();
        if isempty(idx)
            return
        end
        state.markers(idx).visible = logical(source.Value);
        redrawMarkers();
        updateMarkerControls();
    end

    function onShowMarkersChanged(source, ~)
        state.showMarkers = logical(source.Value);
        redrawMarkers();
        updateMarkerControls();
    end

    function onDeleteMarker(~, ~)
        idx = selectedMarkerIndex();
        if isempty(idx)
            return
        end
        markerId = state.markers(idx).id;
        deleteGraphicsHandle(state.markers(idx).graphics);
        state.markers(idx) = [];
        if isempty(state.markers)
            state.selectedMarkerId = [];
        else
            state.selectedMarkerId = state.markers(min(idx, numel(state.markers))).id;
        end
        cancelMarkerPlacement();
        redrawMarkers();
        updateMarkerControls();
        logMessage(sprintf('Marker %d deleted.', markerId));
    end

    function onClearMarkers(~, ~)
        for markerIndex = 1:numel(state.markers)
            deleteGraphicsHandle(state.markers(markerIndex).graphics);
        end
        markerCount = numel(state.markers);
        state.markers = struct('id', {}, 'x', {}, 'y', {}, 'visible', {}, 'graphics', {});
        state.selectedMarkerId = [];
        cancelMarkerPlacement();
        updateMarkerControls();
        logMessage(sprintf('Cleared %d marker(s).', markerCount));
    end

    function idx = selectedMarkerIndex()
        idx = [];
        if isempty(state.selectedMarkerId) || isempty(state.markers)
            return
        end
        idx = find([state.markers.id] == state.selectedMarkerId, 1);
    end

    function updateMarkerControls()
        controlSets = viewControlSets();
        if isempty(controlSets)
            return
        end
        hasMarkers = ~isempty(state.markers);
        if hasMarkers
            labels = arrayfun(@(marker) sprintf('Marker %d (%.0f, %.0f)', ...
                marker.id, marker.x, marker.y), state.markers, 'UniformOutput', false);
            if isempty(selectedMarkerIndex())
                state.selectedMarkerId = state.markers(1).id;
            end
            selectedIndex = selectedMarkerIndex();
            selectedLabel = labels{selectedIndex};
        else
            labels = {'No markers'};
            selectedLabel = 'No markers';
        end

        idx = selectedMarkerIndex();
        hasSelection = ~isempty(idx);
        for controlSetIndex = 1:numel(controlSets)
            controls = controlSets{controlSetIndex};
            controls.MarkerDropDown.Items = labels;
            controls.MarkerDropDown.Value = selectedLabel;
            controls.MarkerDropDown.Enable = matlab.lang.OnOffSwitchState(hasMarkers);
            controls.MoveMarkerButton.Enable = matlab.lang.OnOffSwitchState( ...
                hasSelection && ~isempty(state.nativeFrameSize));
            controls.MarkerVisibleCheckBox.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            controls.DeleteMarkerButton.Enable = matlab.lang.OnOffSwitchState(hasSelection);
            controls.ClearMarkersButton.Enable = matlab.lang.OnOffSwitchState(hasMarkers);
            if hasSelection
                controls.MarkerVisibleCheckBox.Value = state.markers(idx).visible;
            else
                controls.MarkerVisibleCheckBox.Value = false;
            end
            controls.ShowMarkersCheckBox.Value = state.showMarkers;
        end
    end

    function syncRotationControls()
        controlSets = viewControlSets();
        for controlSetIndex = 1:numel(controlSets)
            controls = controlSets{controlSetIndex};
            controls.RotationDropDown.Value = state.rotationDegrees;
        end
    end

    function syncViewControlState()
        hasFrame = ~isempty(state.nativeFrameSize);
        controlSets = viewControlSets();
        for controlSetIndex = 1:numel(controlSets)
            controls = controlSets{controlSetIndex};
            controls.ZoomInButton.Enable = matlab.lang.OnOffSwitchState(hasFrame);
            controls.ZoomOutButton.Enable = matlab.lang.OnOffSwitchState(hasFrame);
            controls.FitViewButton.Enable = matlab.lang.OnOffSwitchState(hasFrame);
            controls.AddMarkerButton.Enable = matlab.lang.OnOffSwitchState(hasFrame);
        end
    end

    function controlSets = viewControlSets()
        controlSets = {};
        if viewControlSetIsValid(ui.MainViewControls)
            controlSets{end + 1} = ui.MainViewControls;
        end
        if viewControlSetIsValid(ui.PopoutViewControls)
            controlSets{end + 1} = ui.PopoutViewControls;
        end
    end

    function tf = viewControlSetIsValid(controls)
        tf = isstruct(controls) && isfield(controls, 'RotationDropDown') && ...
            ~isempty(controls.RotationDropDown) && isvalid(controls.RotationDropDown);
    end

    function redrawMarkers()
        resetMarkerGraphics();
        if ~state.showMarkers || isempty(state.nativeFrameSize)
            return
        end
        [displayHeight, displayWidth] = displayedFrameDimensions();
        crossRadius = max(8, round(min(displayHeight, displayWidth) * 0.015));
        selectedId = state.selectedMarkerId;

        for markerIndex = 1:numel(state.markers)
            marker = state.markers(markerIndex);
            if ~marker.visible
                continue
            end
            [displayX, displayY] = nativeToDisplayPoint(marker.x, marker.y);
            color = markerColor(marker.id);
            lineWidth = 0.75;
            if ~isempty(selectedId) && marker.id == selectedId
                lineWidth = 1.25;
            end
            callback = @(~, ~) selectMarker(marker.id);
            graphics = drawMarkerCross(ui.Axes, displayX, displayY, ...
                crossRadius, displayWidth, displayHeight, color, lineWidth, callback);
            if isPopoutOpen()
                popoutGraphics = drawMarkerCross(state.popoutAxes, displayX, displayY, ...
                    crossRadius, displayWidth, displayHeight, color, lineWidth, callback);
                graphics = [graphics; popoutGraphics]; %#ok<AGROW>
            end
            state.markers(markerIndex).graphics = graphics;
        end
    end

    function graphics = drawMarkerCross(axesHandle, displayX, displayY, ...
            crossRadius, displayWidth, displayHeight, color, lineWidth, callback)
        graphics = gobjects(2, 1);
        graphics(1) = line(axesHandle, ...
                [max(1, displayX - crossRadius), min(displayWidth, displayX + crossRadius)], ...
                [displayY, displayY], ...
                'Color', color, 'LineWidth', lineWidth, ...
                'ButtonDownFcn', callback, 'PickableParts', 'all', 'HitTest', 'on');
        graphics(2) = line(axesHandle, ...
                [displayX, displayX], ...
                [max(1, displayY - crossRadius), min(displayHeight, displayY + crossRadius)], ...
                'Color', color, 'LineWidth', lineWidth, ...
                'ButtonDownFcn', callback, 'PickableParts', 'all', 'HitTest', 'on');
    end

    function resetMarkerGraphics()
        for markerIndex = 1:numel(state.markers)
            deleteGraphicsHandle(state.markers(markerIndex).graphics);
            state.markers(markerIndex).graphics = gobjects(0);
        end
    end

    function color = markerColor(markerId)
        palette = lines(7);
        color = palette(mod(markerId - 1, size(palette, 1)) + 1, :);
    end

    function [displayHeight, displayWidth] = displayedFrameDimensions()
        nativeHeight = state.nativeFrameSize(1);
        nativeWidth = state.nativeFrameSize(2);
        if state.rotationDegrees == 90 || state.rotationDegrees == 270
            displayHeight = nativeWidth;
            displayWidth = nativeHeight;
        else
            displayHeight = nativeHeight;
            displayWidth = nativeWidth;
        end
    end

    function [displayX, displayY] = nativeToDisplayPoint(nativeX, nativeY)
        nativeHeight = state.nativeFrameSize(1);
        nativeWidth = state.nativeFrameSize(2);
        switch state.rotationDegrees
            case 90
                displayX = nativeHeight - nativeY + 1;
                displayY = nativeX;
            case 180
                displayX = nativeWidth - nativeX + 1;
                displayY = nativeHeight - nativeY + 1;
            case 270
                displayX = nativeY;
                displayY = nativeWidth - nativeX + 1;
            otherwise
                displayX = nativeX;
                displayY = nativeY;
        end
    end

    function [nativeX, nativeY] = displayToNativePoint(displayX, displayY)
        nativeHeight = state.nativeFrameSize(1);
        nativeWidth = state.nativeFrameSize(2);
        switch state.rotationDegrees
            case 90
                nativeX = displayY;
                nativeY = nativeHeight - displayX + 1;
            case 180
                nativeX = nativeWidth - displayX + 1;
                nativeY = nativeHeight - displayY + 1;
            case 270
                nativeX = nativeWidth - displayY + 1;
                nativeY = displayX;
            otherwise
                nativeX = displayX;
                nativeY = displayY;
        end
        nativeX = min(max(nativeX, 1), nativeWidth);
        nativeY = min(max(nativeY, 1), nativeHeight);
    end

    function deletePreviewListener()
        try
            if ~isempty(state.previewListener) && isvalid(state.previewListener)
                delete(state.previewListener);
            end
        catch
        end
        state.previewListener = [];
    end

    function deleteGraphicsHandle(handles)
        if isempty(handles)
            return
        end
        for handleIndex = 1:numel(handles)
            try
                if isvalid(handles(handleIndex))
                    delete(handles(handleIndex));
                end
            catch
            end
        end
    end

    function text = sizeText(frame)
        dims = size(frame);
        text = sprintf('%d x %d', dims(2), dims(1));
        if numel(dims) >= 3
            text = sprintf('%s x %d', text, dims(3));
        end
    end

    function onSaveImage(~, ~)
        if isempty(state.lastFrame)
            logMessage('No captured image to save. Press Capture first.');
            return
        end

        defaultName = ['mako_capture_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')) '.tif'];
        [fileName, folderName] = uiputfile( ...
            {'*.tif', 'TIFF image (*.tif)'; '*.png', 'PNG image (*.png)'; '*.jpg', 'JPEG image (*.jpg)'}, ...
            'Save captured image', ...
            defaultName);
        if isequal(fileName, 0)
            return
        end

        fullName = fullfile(folderName, fileName);
        try
            imwrite(state.lastFrame, fullName);
            logMessage(['Saved image: ' fullName]);
        catch ME
            logMessage(['Save failed: ' ME.message]);
        end
    end

    function onExposureAutoChanged(~, ~)
        if ~state.isConnected
            return
        end

        if ~hasSourceProperty('ExposureAuto')
            logMessage('ExposureAuto property is not available on this camera/format.');
            return
        end

        try
            if ui.ExposureAutoCheckBox.Value
                safeSetSourceProperty('ExposureAuto', 'Continuous');
            else
                safeSetSourceProperty('ExposureAuto', 'Off');
            end
            refreshCameraControls();
        catch ME
            logMessage(['Exposure auto update failed: ' ME.message]);
        end
    end

    function onApplyExposure(~, ~)
        if ~state.isConnected
            logMessage('Connect to the camera first.');
            return
        end

        exposureProp = firstAvailableProperty({'ExposureTime', 'ExposureTimeAbs'});
        if isempty(exposureProp)
            logMessage('No ExposureTime property found.');
            return
        end

        try
            if hasSourceProperty('ExposureAuto')
                safeSetSourceProperty('ExposureAuto', 'Off');
                ui.ExposureAutoCheckBox.Value = false;
            end
            safeSetSourceProperty(exposureProp, ui.ExposureEdit.Value);
            refreshCameraControls();
            logMessage(sprintf('Set %s to %.6g.', exposureProp, ui.ExposureEdit.Value));
        catch ME
            logMessage(['Exposure update failed: ' ME.message]);
        end
    end

    function onGainAutoChanged(~, ~)
        if ~state.isConnected
            return
        end

        if ~hasSourceProperty('GainAuto')
            logMessage('GainAuto property is not available on this camera/format.');
            return
        end

        try
            if ui.GainAutoCheckBox.Value
                safeSetSourceProperty('GainAuto', 'Continuous');
            else
                safeSetSourceProperty('GainAuto', 'Off');
            end
            refreshCameraControls();
        catch ME
            logMessage(['Gain auto update failed: ' ME.message]);
        end
    end

    function onApplyGain(~, ~)
        if ~state.isConnected
            logMessage('Connect to the camera first.');
            return
        end

        gainProp = firstAvailableProperty({'Gain', 'GainRaw'});
        if isempty(gainProp)
            logMessage('No Gain property found.');
            return
        end

        try
            if hasSourceProperty('GainAuto')
                safeSetSourceProperty('GainAuto', 'Off');
                ui.GainAutoCheckBox.Value = false;
            end
            safeSetSourceProperty(gainProp, ui.GainEdit.Value);
            refreshCameraControls();
            logMessage(sprintf('Set %s to %.6g.', gainProp, ui.GainEdit.Value));
        catch ME
            logMessage(['Gain update failed: ' ME.message]);
        end
    end

    function onApplyFrameRate(~, ~)
        if ~state.isConnected
            logMessage('Connect to the camera first.');
            return
        end

        rateProp = firstAvailableProperty({'AcquisitionFrameRate', 'AcquisitionFrameRateAbs'});
        if isempty(rateProp)
            logMessage('No AcquisitionFrameRate property found.');
            return
        end

        try
            if hasSourceProperty('AcquisitionFrameRateEnable')
                safeSetSourceProperty('AcquisitionFrameRateEnable', true);
            end
            safeSetSourceProperty(rateProp, ui.FrameRateEdit.Value);
            refreshCameraControls();
            logMessage(sprintf('Set %s to %.6g.', rateProp, ui.FrameRateEdit.Value));
        catch ME
            logMessage(['Frame rate update failed: ' ME.message]);
        end
    end

    function refreshCameraControls()
        if isempty(state.src)
            return
        end

        exposureAutoAvailable = hasSourceProperty('ExposureAuto');
        ui.ExposureAutoCheckBox.Enable = matlab.lang.OnOffSwitchState(exposureAutoAvailable);
        if exposureAutoAvailable
            value = safeGetSourceProperty('ExposureAuto');
            ui.ExposureAutoCheckBox.Value = isAutoValue(value);
        else
            ui.ExposureAutoCheckBox.Value = false;
        end

        exposureProp = firstAvailableProperty({'ExposureTime', 'ExposureTimeAbs'});
        ui.ExposureEdit.Enable = matlab.lang.OnOffSwitchState(~isempty(exposureProp));
        ui.ApplyExposureButton.Enable = matlab.lang.OnOffSwitchState(~isempty(exposureProp));
        if ~isempty(exposureProp)
            ui.ExposureEdit.Value = double(safeGetSourceProperty(exposureProp));
        end

        gainAutoAvailable = hasSourceProperty('GainAuto');
        ui.GainAutoCheckBox.Enable = matlab.lang.OnOffSwitchState(gainAutoAvailable);
        if gainAutoAvailable
            value = safeGetSourceProperty('GainAuto');
            ui.GainAutoCheckBox.Value = isAutoValue(value);
        else
            ui.GainAutoCheckBox.Value = false;
        end

        gainProp = firstAvailableProperty({'Gain', 'GainRaw'});
        ui.GainEdit.Enable = matlab.lang.OnOffSwitchState(~isempty(gainProp));
        ui.ApplyGainButton.Enable = matlab.lang.OnOffSwitchState(~isempty(gainProp));
        if ~isempty(gainProp)
            ui.GainEdit.Value = double(safeGetSourceProperty(gainProp));
        end

        rateProp = firstAvailableProperty({'AcquisitionFrameRate', 'AcquisitionFrameRateAbs'});
        ui.FrameRateEdit.Enable = matlab.lang.OnOffSwitchState(~isempty(rateProp));
        ui.ApplyFrameRateButton.Enable = matlab.lang.OnOffSwitchState(~isempty(rateProp));
        if ~isempty(rateProp)
            ui.FrameRateEdit.Value = double(safeGetSourceProperty(rateProp));
        end

        refreshReadouts();
    end

    function refreshReadouts()
        exposureProp = firstAvailableProperty({'ExposureTime', 'ExposureTimeAbs'});
        if ~isempty(exposureProp)
            ui.ExposureReadoutLabel.Text = sprintf('Exposure: %.6g us', double(safeGetSourceProperty(exposureProp)));
        else
            ui.ExposureReadoutLabel.Text = 'Exposure: -';
        end

        gainProp = firstAvailableProperty({'Gain', 'GainRaw'});
        if ~isempty(gainProp)
            ui.GainReadoutLabel.Text = sprintf('Gain: %.6g', double(safeGetSourceProperty(gainProp)));
        else
            ui.GainReadoutLabel.Text = 'Gain: -';
        end
    end

    function tf = isAutoValue(value)
        if isstring(value) || ischar(value)
            tf = any(strcmpi(char(value), {'Continuous', 'Once'}));
        else
            tf = logical(value);
        end
    end

    function propName = firstAvailableProperty(names)
        propName = '';
        for k = 1:numel(names)
            if hasSourceProperty(names{k})
                propName = names{k};
                return
            end
        end
    end

    function tf = hasSourceProperty(propName)
        tf = false;
        if isempty(state.src)
            return
        end
        try
            tf = isprop(state.src, propName);
        catch
            tf = false;
        end
    end

    function value = safeGetSourceProperty(propName)
        value = [];
        if ~hasSourceProperty(propName)
            return
        end
        value = state.src.(propName);
    end

    function safeSetSourceProperty(propName, value)
        if ~hasSourceProperty(propName)
            error('Property %s is not available.', propName);
        end
        state.src.(propName) = value;
    end

    function setStatus(isConnected, text)
        if isConnected
            ui.StatusLamp.Color = [0.2, 0.7, 0.25];
        else
            ui.StatusLamp.Color = [0.85, 0.2, 0.2];
        end
        ui.StatusLabel.Text = text;
    end

    function updateControlState()
        hasDevice = ~isempty(state.devices);
        ui.ConnectButton.Enable = matlab.lang.OnOffSwitchState(hasDevice && ~state.isConnected);
        ui.DisconnectButton.Enable = matlab.lang.OnOffSwitchState(state.isConnected);
        ui.DeviceDropDown.Enable = matlab.lang.OnOffSwitchState(~state.isConnected);
        ui.FormatDropDown.Enable = matlab.lang.OnOffSwitchState(hasDevice && ~state.isConnected);
        ui.RefreshButton.Enable = matlab.lang.OnOffSwitchState(~state.isConnected);
        ui.StartPreviewButton.Enable = matlab.lang.OnOffSwitchState(state.isConnected && ~state.isPreviewing);
        ui.StopPreviewButton.Enable = matlab.lang.OnOffSwitchState(state.isConnected && state.isPreviewing);
        ui.CaptureButton.Enable = matlab.lang.OnOffSwitchState(state.isConnected);
        ui.SaveButton.Enable = matlab.lang.OnOffSwitchState(~isempty(state.lastFrame));

        controlEnabled = state.isConnected;
        ui.ExposureAutoCheckBox.Enable = matlab.lang.OnOffSwitchState(controlEnabled && hasSourceProperty('ExposureAuto'));
        ui.ApplyExposureButton.Enable = matlab.lang.OnOffSwitchState(controlEnabled && ~isempty(firstAvailableProperty({'ExposureTime', 'ExposureTimeAbs'})));
        ui.ExposureEdit.Enable = ui.ApplyExposureButton.Enable;
        ui.GainAutoCheckBox.Enable = matlab.lang.OnOffSwitchState(controlEnabled && hasSourceProperty('GainAuto'));
        ui.ApplyGainButton.Enable = matlab.lang.OnOffSwitchState(controlEnabled && ~isempty(firstAvailableProperty({'Gain', 'GainRaw'})));
        ui.GainEdit.Enable = ui.ApplyGainButton.Enable;
        ui.ApplyFrameRateButton.Enable = matlab.lang.OnOffSwitchState(controlEnabled && ~isempty(firstAvailableProperty({'AcquisitionFrameRate', 'AcquisitionFrameRateAbs'})));
        ui.FrameRateEdit.Enable = ui.ApplyFrameRateButton.Enable;
        hasFrame = ~isempty(state.nativeFrameSize);
        ui.PopOutButton.Enable = matlab.lang.OnOffSwitchState(hasFrame);
        syncViewControlState();
        updateMarkerControls();
    end

    function logGentlInstallHelp()
        logMessage('MATLAB cannot find the gentl adaptor.');
        if isGenicamSupportPackageInstalled()
            logMessage('GenICam support package appears to be installed. Restart MATLAB, then run this app again.');
        else
            logMessage('Install Image Acquisition Toolbox Support Package for GenICam Interface, then restart MATLAB.');
            logMessage('In MATLAB: Home > Add-Ons > Get Hardware Support Packages > search "GenICam".');
        end
        gentlPath = getenv('GENICAM_GENTL64_PATH');
        if strlength(string(gentlPath)) > 0
            logMessage(['GENICAM_GENTL64_PATH is set: ' gentlPath]);
        else
            logMessage('GENICAM_GENTL64_PATH is empty. Vimba X may need to be reinstalled after the MATLAB support package.');
        end
    end

    function refreshImageAcquisitionCache()
        try
            rehash toolboxcache
        catch
        end
        try
            imaqreset
        catch
        end
    end

    function tf = isGenicamSupportPackageInstalled()
        tf = false;
        try
            packages = matlabshared.supportpkg.getInstalled;
            if isempty(packages)
                return
            end
            names = string({packages.Name});
            tf = any(contains(names, 'GenICam', 'IgnoreCase', true));
        catch
            tf = false;
        end
    end

    function logMessage(message)
        if strcmp(string(message), state.lastLogMessage)
            return
        end
        state.lastLogMessage = string(message);
        timestamp = char(datetime('now', 'Format', 'HH:mm:ss'));
        line = sprintf('[%s] %s', timestamp, message);
        value = ui.LogTextArea.Value;
        if ischar(value)
            value = {value};
        end
        value = [{line}; value(:)];
        maxLines = 200;
        if numel(value) > maxLines
            value = value(1:maxLines);
        end
        ui.LogTextArea.Value = value;
        drawnow limitrate
    end

    function onCloseRequested(~, ~)
        shutdownController();
        if ownsFigure && ~isempty(fig) && isvalid(fig)
            delete(fig);
        end
    end

    function shutdownController()
        try
            stopPreviewIfNeeded();
            cleanupVideo();
            onClosePopout(false);
        catch
        end
    end

    function tf = controllerIsConnected()
        tf = state.isConnected;
    end

    function notifyConnectionStateChanged()
        if ~isfield(options, 'stateChangedFcn') || isempty(options.stateChangedFcn)
            return
        end
        try
            options.stateChangedFcn(state.isConnected);
        catch
        end
    end

    function frame = controllerCaptureFrame()
        if ~state.isConnected
            error('Mako camera is not connected.');
        end
        frame = getsnapshot(state.vid);
        state.lastFrame = frame;
        showFrame(frame);
        refreshReadouts();
        updateControlState();
    end
end
