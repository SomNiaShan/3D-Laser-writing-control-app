function zValues = imagingZPositions(zStart, zEnd, zStep)
if abs(zEnd - zStart) <= 1e-9
    zValues = zStart;
    return;
end

signedStep = sign(zEnd - zStart) * abs(zStep);
zValues = zStart:signedStep:zEnd;
if isempty(zValues)
    zValues = zStart;
end
if abs(zValues(end) - zEnd) > 1e-9
    zValues(end + 1) = zEnd;
end
zValues = zValues(:).';
end
