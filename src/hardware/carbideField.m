function value = carbideField(source, fieldNames, defaultValue)
if nargin < 3
    defaultValue = [];
end
value = defaultValue;
if isempty(source) || ~isstruct(source)
    return;
end

sourceFields = fieldnames(source);
fieldNames = string(fieldNames);
for nameIndex = 1:numel(fieldNames)
    matchIndex = find(strcmpi(sourceFields, char(fieldNames(nameIndex))), 1, 'first');
    if ~isempty(matchIndex)
        value = source.(sourceFields{matchIndex});
        return;
    end
end
end
