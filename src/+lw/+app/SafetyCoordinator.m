classdef SafetyCoordinator < handle
    %SAFETYCOORDINATOR Ordered, exception-isolated STOP and shutdown logic.

    properties (SetAccess = private)
        Model
        Ports
        IsShuttingDown = false
    end

    methods
        function obj = SafetyCoordinator(model, ports)
            arguments
                model (1, 1) lw.app.Model
                ports (1, 1) struct
            end
            obj.Model = model;
            obj.Ports = lw.app.validatePorts("SafetyCoordinator", ports, [ ...
                "stopFlirLive", "requestStageStop", "forceLaserSafeOff", ...
                "stopFlirAcquisition", "deleteFlirLive", "stopPositionTimer", ...
                "stopCarbideTimer", "closeSlmWindow", "disconnectBatchSlm", ...
                "shutdownMako", "finalizeRunLog", "disconnectAll", "deleteFigure", ...
                "updateStopStatus", "syncAll"]);
        end

        function requestStop(obj)
            wasPaused = obj.Model.State.isPaused;
            wasBusy = obj.Model.State.isBusy;

            obj.Model.State.stopRequested = true;
            obj.Model.State.pauseRequested = false;
            obj.Model.PausedManualMotionActive = false;
            obj.Model.State.isPaused = false;
            obj.Model.State.resumeContext = [];

            obj.safeInvoke('stopFlirLive', false);
            obj.safeInvoke('requestStageStop');
            obj.safeInvoke('forceLaserSafeOff');
            obj.safeInvoke('stopFlirAcquisition');
            obj.safeInvoke('updateStopStatus', wasPaused, wasBusy);
            obj.safeInvoke('syncAll');
        end

        function shutdown(obj)
            if obj.IsShuttingDown
                return;
            end
            obj.IsShuttingDown = true;

            obj.Model.State.stopRequested = true;
            obj.Model.State.pauseRequested = false;
            obj.Model.PausedManualMotionActive = false;
            obj.Model.State.isPaused = false;
            obj.Model.State.resumeContext = [];

            orderedSteps = { ...
                {'stopFlirLive', false}, ...
                {'requestStageStop'}, ...
                {'forceLaserSafeOff'}, ...
                {'stopFlirAcquisition'}, ...
                {'deleteFlirLive'}, ...
                {'stopPositionTimer'}, ...
                {'stopCarbideTimer'}, ...
                {'closeSlmWindow'}, ...
                {'disconnectBatchSlm'}, ...
                {'shutdownMako'}, ...
                {'finalizeRunLog'}, ...
                {'disconnectAll'}, ...
                {'deleteFigure'}};
            for stepIndex = 1:numel(orderedSteps)
                obj.safeInvoke(orderedSteps{stepIndex}{:});
            end
        end
    end

    methods (Access = private)
        function safeInvoke(obj, portName, varargin)
            if ~isfield(obj.Ports, portName) || isempty(obj.Ports.(portName))
                return;
            end
            try
                obj.Ports.(portName)(varargin{:});
            catch
            end
        end
    end
end
