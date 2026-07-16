function validateUniqueZSweepMatrixParameters(parameters)
parameters = parameters(parameters ~= "");
if numel(unique(parameters)) ~= numel(parameters)
    error('Z Sweep matrix X, Y, and block parameters must all be different.');
end
end
