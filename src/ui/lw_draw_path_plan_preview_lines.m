function lw_draw_path_plan_preview_lines(ax, pathRows, yDisplayFcn)
%LW_DRAW_PATH_PLAN_PREVIEW_LINES Draw explicit laser-on/off path segments.

if nargin < 3 || isempty(yDisplayFcn)
    yDisplayFcn = @(y) y;
end
laserOn = string(pathRows.laserState) == "on";
onColor = [0.9, 0.12, 0.08];
offColor = [0.45, 0.45, 0.45];
localDrawSegments(pathRows(laserOn, :), '-', onColor, 1.4);
localDrawSegments(pathRows(~laserOn, :), '--', offColor, 0.9);

arrowLimit = min(height(pathRows), 2000);
if arrowLimit == 0
    return;
end
arrowIndices = unique(round(linspace(1, height(pathRows), arrowLimit)));
arrowRows = pathRows(arrowIndices, :);
arrowOn = string(arrowRows.laserState) == "on";
localDrawArrows(arrowRows(arrowOn, :), onColor);
localDrawArrows(arrowRows(~arrowOn, :), offColor);

    function localDrawSegments(rows, lineStyle, color, width)
        if height(rows) == 0
            return;
        end
        x = reshape([rows.x, rows.x2, nan(height(rows), 1)].', [], 1);
        y = reshape([rows.y, rows.y2, nan(height(rows), 1)].', [], 1);
        z = reshape([rows.z, rows.z2, nan(height(rows), 1)].', [], 1);
        plot3(ax, x, yDisplayFcn(y), z, lineStyle, ...
            'Color', color, 'LineWidth', width);
    end

    function localDrawArrows(rows, color)
        if height(rows) == 0
            return;
        end
        startY = yDisplayFcn(rows.y);
        endY = yDisplayFcn(rows.y2);
        quiver3(ax, rows.x, startY, rows.z, ...
            rows.x2 - rows.x, endY - startY, rows.z2 - rows.z, ...
            0, 'Color', color, 'LineWidth', 0.9, 'MaxHeadSize', 0.8);
    end
end
