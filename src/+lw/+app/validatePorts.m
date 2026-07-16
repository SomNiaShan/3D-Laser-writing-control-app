function ports = validatePorts(ownerName, ports, requiredNames)
%VALIDATEPORTS Fail fast when a controller dependency is missing.

arguments
    ownerName (1, 1) string
    ports (1, 1) struct
    requiredNames (1, :) string
end

availableNames = string(fieldnames(ports));
missingNames = requiredNames(~ismember(requiredNames, availableNames));
emptyNames = requiredNames(ismember(requiredNames, availableNames));
emptyNames = emptyNames(arrayfun(@(name) isempty(ports.(name)), emptyNames));
invalidNames = unique([missingNames, emptyNames], 'stable');
if ~isempty(invalidNames)
    error('lw:app:MissingDependency', '%s is missing required dependencies: %s.', ...
        ownerName, strjoin(invalidNames, ', '));
end
end
