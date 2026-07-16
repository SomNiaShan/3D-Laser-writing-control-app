function lw_normalize_dynamic_ui_for_screenshot(fig)
%LW_NORMALIZE_DYNAMIC_UI_FOR_SCREENSHOT Stabilize runtime-only GUI details.

textAreas = findall(fig, 'Type', 'uitextarea');
for index = 1:numel(textAreas)
    textAreas(index).Value = {''};
end

makoTabs = findall(fig, 'Type', 'uitab', 'Title', 'Mako Monitor & Alignment');
for tabIndex = 1:numel(makoTabs)
    objects = findall(makoTabs(tabIndex));
    for objectIndex = 1:numel(objects)
        object = objects(objectIndex);
        normalizeEnableState(object);
        normalizeMakoStatusText(object);
        normalizeMakoDiscoveryDropDown(object);
    end
end
drawnow;
end

function normalizeEnableState(object)
if ~isprop(object, 'Enable')
    return;
end
try
    object.Enable = 'on';
catch
end
end

function normalizeMakoStatusText(object)
if ~isprop(object, 'Text')
    return;
end
try
    value = string(object.Text);
    dynamicStatusText = [ ...
        "Disconnected", "GenTL adaptor not available", ...
        "No camera detected", "Camera detected"];
    if isscalar(value) && any(value == dynamicStatusText)
        object.Text = 'Camera discovery state';
    end
catch
end
end

function normalizeMakoDiscoveryDropDown(object)
if ~isa(object, 'matlab.ui.control.DropDown') || isempty(object.Parent) || ...
        ~isa(object.Parent, 'matlab.ui.container.GridLayout') || ...
        numel(object.Parent.RowHeight) ~= 20
    return;
end

if isequal(object.Layout.Row, 2)
    object.Items = {'Camera baseline'};
    object.Value = 'Camera baseline';
elseif isequal(object.Layout.Row, 4)
    object.Items = {'Format baseline'};
    object.Value = 'Format baseline';
end
end
