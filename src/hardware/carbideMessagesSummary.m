function summaryText = carbideMessagesSummary(rawValue)
messages = strings(1, 0);
if isempty(rawValue)
    summaryText = "";
    return;
end

if iscell(rawValue)
    for messageIndex = 1:numel(rawValue)
        childText = carbideMessagesSummary(rawValue{messageIndex});
        if strlength(childText) > 0
            messages(end + 1) = childText; %#ok<AGROW>
        end
    end
elseif isstruct(rawValue)
    for messageIndex = 1:numel(rawValue)
        item = rawValue(messageIndex);
        itemText = carbideTextField(item, ["Message", "Text", "Description", "Name", "Code"], "");
        if strlength(strtrim(itemText)) == 0
            itemText = string(compactJsonText(item));
        end
        messages(end + 1) = itemText; %#ok<AGROW>
    end
elseif isstring(rawValue) || ischar(rawValue)
    messages = string(rawValue);
elseif isnumeric(rawValue) || islogical(rawValue)
    if any(double(rawValue(:)) ~= 0)
        messages = string(mat2str(rawValue));
    end
else
    messages = string(rawValue);
end

messages = string(strtrim(cellstr(messages)));
messages = messages(strlength(messages) > 0);
if isempty(messages)
    summaryText = "";
else
    summaryText = strjoin(messages, '; ');
end
end
