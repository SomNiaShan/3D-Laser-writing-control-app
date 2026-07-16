function flir = lw_flir_default_state()
%LW_FLIR_DEFAULT_STATE Create the default FLIR/Spinnaker runtime state.

flir = struct();
flir.system = [];
flir.camList = [];
flir.cam = [];
flir.nodeMap = [];
flir.tlNodeMap = [];
flir.devices = struct('Index', {}, 'Label', {}, 'Serial', {});
flir.selectedDevice = [];
flir.lastFrame = [];
flir.lastFrameInfo = struct();
flir.currentRoi = struct();
flir.isConnected = false;
flir.isAcquiring = false;
flir.isGrabbing = false;
flir.sdkLoaded = false;
flir.sdkPath = '';
flir.sdkVersion = '';
flir.lastExposureTimeUs = NaN;
flir.lastGain = NaN;
end
