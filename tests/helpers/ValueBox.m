classdef ValueBox < handle
    properties
        Value
    end

    methods
        function obj = ValueBox(value)
            obj.Value = value;
        end
    end
end
