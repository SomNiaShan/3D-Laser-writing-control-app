function token = lw_slm_filename_token(snapshot)
%LW_SLM_FILENAME_TOKEN Build a compact filename token from SLM options.

token = "";
if ~isstruct(snapshot) || ~isfield(snapshot, 'options') || ~isstruct(snapshot.options)
    return;
end

options = snapshot.options;
globalAdjustments = struct();
if isfield(snapshot, 'globalAdjustments') && isstruct(snapshot.globalAdjustments)
    globalAdjustments = snapshot.globalAdjustments;
end

parts = strings(1, 0);
parts(end + 1) = "beta=" + slmFilenameNumber(slmOptionValue(options, 'axiconConeAngleDeg'));
parts(end + 1) = "rc=" + slmFilenameNumber(slmOptionValue(options, 'axiconRadialCycles'));
parts(end + 1) = "v=" + slmFilenameNumber(slmOptionValue(options, 'vortexCharge'));
parts(end + 1) = "gamma=" + slmFilenameNumber(slmOptionValue(options, 'helicalGamma'));
parts(end + 1) = "order=" + slmFilenameNumber(slmOptionValue(options, 'helicalOrder'));
parts(end + 1) = "oi=" + slmFilenameNumber(slmOptionValue(options, 'omegaInner'));
parts(end + 1) = "oo=" + slmFilenameNumber(slmOptionValue(options, 'omegaOuter'));
parts(end + 1) = "aperture=" + slmFilenameApertureRadius( ...
    slmOptionValue(globalAdjustments, 'apertureRadiusPx'));

token = strjoin(parts, "_");
token = string(sanitizeFileComponent(token, ''));
end

function value = slmOptionValue(options, fieldName)
value = NaN;
if isstruct(options) && isfield(options, fieldName)
    try
        value = double(options.(fieldName));
    catch
        value = NaN;
    end
end
if ~isscalar(value)
    value = NaN;
end
end

function text = slmFilenameNumber(value)
if ~isfinite(value)
    text = "nan";
    return;
end
if abs(value - round(value)) < 1e-9
    text = string(sprintf('%.0f', value));
else
    text = string(sprintf('%.6g', value));
end
text = replace(text, "+", "");
end

function text = slmFilenameApertureRadius(value)
if isinf(value)
    text = "full";
    return;
end
text = slmFilenameNumber(value);
end

function textValue = sanitizeFileComponent(rawValue, fallback)
textValue = char(strtrim(string(rawValue)));
if isempty(textValue)
    textValue = fallback;
end
textValue = regexprep(textValue, '[^\w\.=-]+', '_');
textValue = regexprep(textValue, '_+', '_');
textValue = regexprep(textValue, '^_+|_+$', '');
if isempty(textValue)
    textValue = fallback;
end
end
