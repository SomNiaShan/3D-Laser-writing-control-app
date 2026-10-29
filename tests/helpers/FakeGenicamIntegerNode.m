classdef FakeGenicamIntegerNode < handle
    %FAKEGENICAMINTEGERNODE GenICam integer node that rejects invalid writes like a camera.

    properties
        Min = 0
        Increment = 1
        IsReadable = true
        IsWritable = true
        MaxFcn
        Writes = zeros(1, 0)
    end

    properties (Dependent)
        Value
        Max
    end

    properties (Access = private)
        StoredValue
    end

    methods
        function obj = FakeGenicamIntegerNode(value, minValue, increment, maxFcn)
            obj.StoredValue = double(value);
            obj.Min = minValue;
            obj.Increment = increment;
            if nargin >= 4
                obj.MaxFcn = maxFcn;
            end
        end

        function value = get.Value(obj)
            value = obj.StoredValue;
        end

        function set.Value(obj, value)
            value = double(value);
            if ~obj.IsWritable
                error('fake:NotWritable', 'Node is not writable.');
            end
            maxValue = obj.Max;
            if value < obj.Min || value > maxValue || mod(value - obj.Min, obj.Increment) ~= 0
                error('fake:OutOfRange', 'Value %d is invalid (min %d, max %d, increment %d).', ...
                    value, obj.Min, maxValue, obj.Increment);
            end
            obj.StoredValue = value;
            obj.Writes(end + 1) = value;
        end

        function value = get.Max(obj)
            value = obj.MaxFcn();
        end
    end
end
