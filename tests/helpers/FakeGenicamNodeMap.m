classdef FakeGenicamNodeMap < handle
    %FAKEGENICAMNODEMAP Minimal Spinnaker-style node map for FLIR ROI tests.

    properties
        Nodes
    end

    methods
        function obj = FakeGenicamNodeMap()
            obj.Nodes = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function add(obj, name, node)
            obj.Nodes(char(name)) = node;
        end

        function tf = ContainsKey(obj, name)
            tf = isKey(obj.Nodes, char(name));
        end

        function node = Item(obj, name)
            node = obj.Nodes(char(name));
        end
    end
end
