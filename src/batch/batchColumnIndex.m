function index = batchColumnIndex(name)
names = string(batchColumnNames());
index = find(names == string(name), 1, 'first');
if isempty(index)
    error('Unknown batch table column: %s', char(string(name)));
end
end
