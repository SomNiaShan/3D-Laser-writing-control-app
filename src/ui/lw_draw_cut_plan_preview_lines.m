function lw_draw_cut_plan_preview_lines(ax, cutRows, yDisplayFcn)
%LW_DRAW_CUT_PLAN_PREVIEW_LINES Draw grouped cut-plan lead/cut/exit paths.

if nargin < 3 || isempty(yDisplayFcn)
    yDisplayFcn = @(y) y;
end

groups = lw_cut_plan_groups(cutRows);
if isempty(groups)
    return;
end

leadColor = [0.45, 0.45, 0.45];
cutColor = [0.9, 0.12, 0.08];

leadX = [];
leadY = [];
leadZ = [];
cutX = [];
cutY = [];
cutZ = [];
exitX = [];
exitY = [];
exitZ = [];

for iGroup = 1:numel(groups)
    rows = groups(iGroup).rows;
    firstRow = rows(1, :);
    lastRow = rows(end, :);

    leadX = [leadX; firstRow.leadX; firstRow.x; NaN]; %#ok<AGROW>
    leadY = [leadY; firstRow.leadY; firstRow.y; NaN]; %#ok<AGROW>
    leadZ = [leadZ; firstRow.leadZ; firstRow.z; NaN]; %#ok<AGROW>

    cutX = [cutX; rows.x(1); rows.x2(:); NaN]; %#ok<AGROW>
    cutY = [cutY; rows.y(1); rows.y2(:); NaN]; %#ok<AGROW>
    cutZ = [cutZ; rows.z(1); rows.z2(:); NaN]; %#ok<AGROW>

    exitX = [exitX; lastRow.x2; lastRow.exitX; NaN]; %#ok<AGROW>
    exitY = [exitY; lastRow.y2; lastRow.exitY; NaN]; %#ok<AGROW>
    exitZ = [exitZ; lastRow.z2; lastRow.exitZ; NaN]; %#ok<AGROW>
end

plot3(ax, leadX, yDisplayFcn(leadY), leadZ, '--', 'Color', leadColor, 'LineWidth', 0.9);
plot3(ax, cutX, yDisplayFcn(cutY), cutZ, '-', 'Color', cutColor, 'LineWidth', 1.4);
plot3(ax, exitX, yDisplayFcn(exitY), exitZ, ':', 'Color', leadColor, 'LineWidth', 1.0);
end
