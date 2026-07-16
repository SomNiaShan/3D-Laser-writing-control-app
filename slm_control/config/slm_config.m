function config = slm_config()
%SLM_CONFIG Default settings for the HOLOEYE PLUTO-2.1 control scripts.

config.sdkPath = 'C:\Program Files\HOLOEYE Photonics\SLM Display SDK (MATLAB) v4.1.0';
config.sdkEnvVar = 'HEDS_4_1_MATLAB';
config.sdkVersionMajor = 4;
config.sdkVersionMinor = 1;

% Use "name:pluto" for automatic selection. Set to '' if you want the SDK to
% use its default detection behavior or show its own selection UI.
config.preselect = 'name:pluto';

% Preview is a PC-side diagnostic window, not the physical SLM panel itself.
% A scale of 0 means "fit" in the HOLOEYE SDK examples.
config.openPreview = true;
config.previewScale = 0;

config.closeExistingWindowsOnInit = true;
config.printSdkVersion = true;

config.wavelengthNm = 1030.0;
config.blankGray = uint8(128);
config.observationFallbackMs = 15000;
config.patternDir = '';

config.expectedWidthPx = 1920;
config.expectedHeightPx = 1080;
config.pixelPitchUm = 8.0;
config.phaseUnit = 2*pi;
end
