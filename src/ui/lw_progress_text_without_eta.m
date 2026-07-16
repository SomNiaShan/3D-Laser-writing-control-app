function textValue = lw_progress_text_without_eta(textValue)
%LW_PROGRESS_TEXT_WITHOUT_ETA Remove ETA text from a progress label.

textParts = split(string(textValue), " | ETA ");
textValue = textParts(1);
end
