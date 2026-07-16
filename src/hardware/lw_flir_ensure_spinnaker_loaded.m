function flir = lw_flir_ensure_spinnaker_loaded(flir)
%LW_FLIR_ENSURE_SPINNAKER_LOADED Load the Spinnaker .NET assembly.

if nargin < 1 || isempty(flir)
    flir = lw_flir_default_state();
end
if isfield(flir, 'sdkLoaded') && logical(flir.sdkLoaded)
    return;
end

candidates = { ...
    fullfile('C:\Program Files', 'Teledyne', 'Spinnaker', 'bin64', 'vs2015', 'SpinnakerNET_v140.dll'), ...
    fullfile('C:\Program Files', 'FLIR Systems', 'Spinnaker', 'bin64', 'vs2015', 'SpinnakerNET_v140.dll')};

sdkFile = '';
for k = 1:numel(candidates)
    if isfile(candidates{k})
        sdkFile = candidates{k};
        break;
    end
end

if isempty(sdkFile)
    searchRoots = { ...
        fullfile('C:\Program Files', 'Teledyne', 'Spinnaker'), ...
        fullfile('C:\Program Files', 'FLIR Systems', 'Spinnaker')};
    for k = 1:numel(searchRoots)
        if isfolder(searchRoots{k})
            files = dir(fullfile(searchRoots{k}, '**', 'SpinnakerNET_v*.dll'));
            if ~isempty(files)
                sdkFile = fullfile(files(1).folder, files(1).name);
                break;
            end
        end
    end
end

if isempty(sdkFile)
    error('SpinnakerNET DLL was not found. Install Teledyne Spinnaker and close SpinView before connecting.');
end

sdkFolder = fileparts(sdkFile);
currentPath = getenv('PATH');
if ~contains([';' currentPath ';'], [';' sdkFolder ';'], 'IgnoreCase', true)
    setenv('PATH', [sdkFolder ';' currentPath]);
end

NET.addAssembly(sdkFile);
flir.sdkPath = sdkFile;
flir.sdkLoaded = true;
end
