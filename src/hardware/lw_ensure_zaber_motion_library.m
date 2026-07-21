function lw_ensure_zaber_motion_library()
%LW_ENSURE_ZABER_MOTION_LIBRARY Make the Zaber Java API available.
%
% MATLAB R2025a and later can omit Java dependencies bundled in legacy
% toolboxes from the Java class path. Newer Zaber releases provide an
% initializer for this case; older releases require the JAR to be added
% explicitly.

className = 'zaber.motion.ascii.Connection';
if hasOpenSerialPort(className)
    return;
end

if exist('zaberMotionLibraryInit', 'file') == 2
    zaberMotionLibraryInit();
    if hasOpenSerialPort(className)
        return;
    end
end

jarName = "motion-library-jar-with-dependencies.jar";
pathEntries = string(strsplit(path, pathsep));
jarCandidates = fullfile(pathEntries, jarName);

appData = string(getenv('APPDATA'));
if strlength(appData) > 0
    addOnRoot = fullfile(appData, "MathWorks", "MATLAB Add-Ons", "Toolboxes");
    jarCandidates(end + 1) = fullfile( ...
        addOnRoot, "Zaber Motion Library", jarName);
    jarCandidates(end + 1) = fullfile( ...
        addOnRoot, "Zaber Motion Library (Legacy)", jarName);
end

jarCandidates = unique(jarCandidates, 'stable');
jarIndex = find(isfile(jarCandidates), 1, 'first');
if isempty(jarIndex)
    error('lw:stage:ZaberLibraryNotFound', ...
        ['Zaber Motion Library is installed but its Java archive could ' ...
        'not be found. Reinstall or update the Zaber Motion Library add-on.']);
end

javaaddpath(char(jarCandidates(jarIndex)));
if ~hasOpenSerialPort(className)
    error('lw:stage:ZaberLibraryLoadFailed', ...
        ['The Zaber Motion Library Java archive was added, but ' ...
        'zaber.motion.ascii.Connection is still unavailable.']);
end
end

function tf = hasOpenSerialPort(className)
try
    methodNames = methods(className);
    tf = any(strcmp(methodNames, 'openSerialPort'));
catch
    tf = false;
end
end
