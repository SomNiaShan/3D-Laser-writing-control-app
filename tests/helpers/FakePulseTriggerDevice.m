classdef FakePulseTriggerDevice < handle
    %FAKEPULSETRIGGERDEVICE Record electrical gate requests without hardware.
    properties
        GateActions = strings(1, 0)
        GateChannels = zeros(1, 0)
        Schedules = {}
        Voltages = zeros(1, 0)
    end
    methods
        function device = getDevice(obj)
            device = obj;
        end
        function io = getIO(obj)
            io = obj;
        end
        function setDigitalOutput(obj, channel, action)
            obj.GateChannels(end + 1) = channel;
            obj.GateActions(end + 1) = string(action.toString());
        end
        function setDigitalOutputSchedule(obj, channel, active, inactive, duration, unit)
            obj.Schedules{end + 1} = struct('channel', channel, ...
                'active', string(active.toString()), ...
                'inactive', string(inactive.toString()), ...
                'duration', duration, 'unit', string(unit.toString()));
        end
        function write(obj, voltage)
            obj.Voltages(end + 1) = voltage;
        end
    end
end
