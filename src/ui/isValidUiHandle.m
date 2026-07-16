function tf = isValidUiHandle(handleValue)
try
    tf = ~isempty(handleValue) && isvalid(handleValue);
catch
    try
        tf = ~isempty(handleValue) && isgraphics(handleValue);
    catch
        tf = false;
    end
end
end
