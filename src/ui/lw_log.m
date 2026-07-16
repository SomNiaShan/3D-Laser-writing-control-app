function line = lw_log(appOrBuffer, message)
%LW_LOG Append a timestamped message to the app log or print it.

timestamp = char(datetime('now', 'Format', 'HH:mm:ss'));
line = sprintf('[%s] %s', timestamp, message);

if nargin < 1 || isempty(appOrBuffer)
    disp(line);
    return;
end

if isstruct(appOrBuffer) || isobject(appOrBuffer)
    try
        appOrBuffer.LogTextArea.Value = [appOrBuffer.LogTextArea.Value; {line}];
        drawnow limitrate;
        try
            scroll(appOrBuffer.LogTextArea, 'bottom');
        catch
        end
        return;
    catch
    end
end

disp(line);
end
