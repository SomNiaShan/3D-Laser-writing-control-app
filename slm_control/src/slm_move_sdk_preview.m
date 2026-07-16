function slm_move_sdk_preview(ctx, columns, rows, columnIndex, rowIndex, margin)
%SLM_MOVE_SDK_PREVIEW Move the HOLOEYE SDK Preview window to a screen tile.

if nargin < 2 || isempty(columns)
    columns = 2;
end
if nargin < 3 || isempty(rows)
    rows = 2;
end
if nargin < 4 || isempty(columnIndex)
    columnIndex = 0;
end
if nargin < 5 || isempty(rowIndex)
    rowIndex = 0;
end
if nargin < 6 || isempty(margin)
    margin = 60;
end

slm = slm_get_handle(ctx);
heds_slmpreview_autoplace_layout_on_secondary_monitor( ...
    slm.slmwindow_id, columns, rows, columnIndex, rowIndex, margin);
end
