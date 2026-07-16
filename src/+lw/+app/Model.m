classdef Model < handle
    %MODEL Shared cross-domain state for the laser writing application.

    properties
        Config
        Services
        State
        Ui
        Figure = []
        Trajectory = []
        TrajectoryInputsDirty = false
        RunProgressText = "0 / 0"
        RunCurrentText = "Idle"
        ImagingProgressText = "0 / 0"
        ImagingCurrentText = "Idle"
        BatchProgressText = "0 / 0"
        BatchCurrentText = "Idle"
        BatchOutputText = ""
        RunEtaStartTic = []
        RunEtaBaselineUnits = 0
        ImagingEtaStartTic = []
        SourceModeMemory = struct()
        CurrentSourceMode = "Imported Points"
        PausedManualMotionActive = false
        ImagingRunActive = false
        LastPositionRefreshTic
        RunLog
        MakoController = []
        SavedStagePositions
        PreviewMaxPoints = 50000
        ZSweepPreviewMaxRuns = 500
        PreviewBounds = struct('x', [], 'y', [], 'z', [])
    end

    methods
        function obj = Model(config, state, services)
            arguments
                config (1, 1) struct
                state (1, 1) struct
                services (1, 1) struct = lw.app.defaultServices()
            end

            obj.Config = config;
            obj.Services = lw.app.validateServices(services);
            obj.State = state;
            obj.Ui = obj.defaultUiState(config, services);
            obj.SavedStagePositions = repmat(struct( ...
                'isSet', false, 'x', NaN, 'y', NaN, 'z', NaN), 1, 4);
            obj.LastPositionRefreshTic = services.clock.tic();
            obj.RunLog = lw_run_log('empty');
        end

        function mergeUi(obj, newUi)
            fieldNames = fieldnames(newUi);
            for fieldIndex = 1:numel(fieldNames)
                obj.Ui.(fieldNames{fieldIndex}) = newUi.(fieldNames{fieldIndex});
            end
        end
    end

    methods (Static, Access = private)
        function ui = defaultUiState(config, services)
            ui = struct();
            ui.PositionTimerHandle = [];
            ui.PositionTimerPeriodSeconds = 0.2;
            ui.PositionPollInProgress = false;
            ui.PositionPollFailureCount = 0;
            ui.SlmControlFigure = [];
            ui.OpenSlmControlButton = [];
            ui.OpenFlirLiveWindowButton = [];
            ui.FlirLiveFigure = [];
            ui.FlirLiveAxes = [];
            ui.FlirLiveStatusLabel = [];
            ui.FlirLiveCameraLabel = [];
            ui.FlirLiveCurrentExposureLabel = [];
            ui.FlirLiveCurrentGainLabel = [];
            ui.FlirLiveButton = [];
            ui.FlirGainField = [];
            ui.FlirApplyGainButton = [];
            ui.FlirLiveExposureField = [];
            ui.FlirLiveApplyExposureButton = [];
            ui.FlirLiveGainField = [];
            ui.FlirLiveApplyGainButton = [];
            ui.FlirLiveTimeoutField = [];
            ui.FlirLivePeriodField = [];
            ui.FlirLiveMarkerCheckBox = [];
            ui.ImagingAutoExposureCheckBox = [];
            ui.ImagingAutoExposureSamplesField = [];
            ui.ImagingAutoExposureSafetyFactorField = [];
            ui.FlirLiveTimerHandle = [];
            ui.FlirLiveEnabled = false;
            ui.FlirLiveFrameCount = 0;
            ui.FlirLiveFailureCount = 0;
            ui.FlirLiveTickInProgress = false;
            ui.FlirLiveLastFrameTic = services.clock.tic();
            ui.FlirLiveTimeoutMs = max(250, min(config.imaging.captureTimeoutMs, 750));
            ui.FlirLivePeriodSeconds = 0.25;
            ui.Stop3DImagingButton = [];
            ui.PreviewColorbar = [];
            ui.PreviewLine = [];
            ui.PreviewScatter = [];
            ui.PreviewPositionMarker = [];
        end
    end
end
