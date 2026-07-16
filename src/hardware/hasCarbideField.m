function tf = hasCarbideField(source, fieldNames)
tf = ~isempty(carbideField(source, fieldNames, []));
end
