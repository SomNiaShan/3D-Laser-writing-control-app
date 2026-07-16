function [signature, hash] = lw_test_ui_signature(fig)
%LW_TEST_UI_SIGNATURE Build a stable structural signature for the app UI.

objects = findall(fig);
records = strings(numel(objects), 1);
for index = 1:numel(objects)
    object = objects(index);
    parts = [ ...
        "class=" + string(class(object)), ...
        ancestorText(object), ...
        propertyText(object, 'Name'), ...
        propertyText(object, 'Title'), ...
        propertyText(object, 'Text'), ...
        propertyText(object, 'Tag'), ...
        propertyText(object, 'Enable'), ...
        propertyText(object, 'Visible'), ...
        propertyText(object, 'Editable'), ...
        propertyText(object, 'Limits'), ...
        propertyText(object, 'RowHeight'), ...
        propertyText(object, 'ColumnWidth'), ...
        propertyText(object, 'Padding'), ...
        propertyText(object, 'RowSpacing'), ...
        propertyText(object, 'ColumnSpacing'), ...
        propertyText(object, 'WordWrap'), ...
        propertyText(object, 'HorizontalAlignment'), ...
        propertyText(object, 'FontWeight'), ...
        propertyText(object, 'FontSize'), ...
        propertyText(object, 'BackgroundColor'), ...
        propertyText(object, 'FontColor'), ...
        positionText(object), ...
        layoutPropertyText(object, 'Row', 'layoutRow'), ...
        layoutPropertyText(object, 'Column', 'layoutColumn'), ...
        callbackText(object, 'CloseRequestFcn'), ...
        callbackText(object, 'ButtonPushedFcn'), ...
        callbackText(object, 'ValueChangedFcn'), ...
        callbackText(object, 'SelectionChangedFcn'), ...
        callbackText(object, 'CellEditCallback'), ...
        callbackText(object, 'CellSelectionCallback')];

    parts = parts(parts ~= "");
    records(index) = strjoin(parts, "|");
end

function text = positionText(object)
text = "";
if isa(object, 'matlab.ui.Figure') || ...
        (~isempty(object.Parent) && isa(object.Parent, 'matlab.ui.container.ButtonGroup'))
    text = propertyText(object, 'Position');
end
end

function text = layoutPropertyText(object, propertyName, outputName)
text = "";
if isprop(object, 'Layout') && ~isempty(object.Layout)
    text = propertyText(object.Layout, propertyName, outputName);
end
end

records = sort(records);
signature = strjoin(records, newline);
hash = sha256(signature);
end

function text = ancestorText(object)
parts = strings(1, 0);
parent = object.Parent;
while ~isempty(parent)
    descriptor = string(class(parent));
    titleText = scalarTextProperty(parent, 'Title');
    nameText = scalarTextProperty(parent, 'Name');
    if titleText ~= ""
        descriptor = descriptor + "[" + titleText + "]";
    elseif nameText ~= ""
        descriptor = descriptor + "[" + nameText + "]";
    end
    parts(end + 1) = descriptor; %#ok<AGROW>
    if ~isprop(parent, 'Parent')
        break;
    end
    parent = parent.Parent;
end
text = "ancestors=" + strjoin(parts, ">");
end

function text = scalarTextProperty(object, propertyName)
text = "";
if ~isprop(object, propertyName)
    return;
end
try
    value = object.(propertyName);
    if ischar(value) || (isstring(value) && isscalar(value))
        text = string(value);
    end
catch
end
end

function text = callbackText(object, propertyName)
text = "";
if ~isprop(object, propertyName)
    return;
end
text = propertyName + "=" + string(~isempty(object.(propertyName)));
end

function text = propertyText(object, propertyName, outputName)
if nargin < 3
    outputName = string(propertyName);
end
text = "";
if ~isprop(object, propertyName)
    return;
end

if isMakoDiscoveryProperty(object, propertyName)
    text = outputName + "=<mako-discovery-state>";
    return;
end

try
    value = object.(propertyName);
    text = outputName + "=" + serializeValue(value);
catch
    text = outputName + "=<unreadable>";
end
end

function tf = isMakoDiscoveryProperty(object, propertyName)
tf = false;
if ~isMakoDescendant(object)
    return;
end

if strcmp(propertyName, 'Enable')
    tf = true;
    return;
end
if ~strcmp(propertyName, 'Text')
    return;
end

try
    value = string(object.Text);
catch
    return;
end
dynamicStatusText = [ ...
    "Disconnected", "GenTL adaptor not available", ...
    "No camera detected", "Camera detected"];
tf = isscalar(value) && any(value == dynamicStatusText);
end

function tf = isMakoDescendant(object)
tf = false;
current = object;
while ~isempty(current)
    if isa(current, 'matlab.ui.container.Tab') && ...
            string(current.Title) == "Mako Monitor & Alignment"
        tf = true;
        return;
    end
    if ~isprop(current, 'Parent')
        return;
    end
    current = current.Parent;
end
end

function text = serializeValue(value)
if isempty(value)
    text = "[]";
elseif ischar(value)
    text = "'" + string(value) + "'";
elseif isstring(value)
    text = "[" + strjoin(value(:).', ",") + "]";
elseif isnumeric(value) || islogical(value)
    text = string(mat2str(value));
elseif iscell(value)
    items = strings(size(value));
    for index = 1:numel(value)
        items(index) = serializeValue(value{index});
    end
    text = "{" + strjoin(items(:).', ",") + "}";
else
    text = "<" + string(class(value)) + ">";
end
end

function hash = sha256(text)
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(char(text), 'UTF-8'));
bytes = typecast(digest.digest(), 'uint8');
hash = lower(string(reshape(dec2hex(bytes, 2).', 1, [])));
end
