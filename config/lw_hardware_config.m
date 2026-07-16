function config = lw_hardware_config()
%LW_HARDWARE_CONFIG Default hardware and motion configuration.

config = struct();

config.stage = struct();
config.stage.comPort = "COM6";
config.stage.deviceOrder = struct('x', 1, 'y', 3, 'z', 2);
% Each detected device in the current setup is a single-axis stage, so the
% correct axis index is 1 for all of them.
config.stage.axisMap = struct('x', 1, 'y', 1, 'z', 1);
config.stage.pulseTriggerAxis = 'x';
config.stage.pulseTriggerChannel = 1;
config.stage.ttlGateWidthUs = 50;
config.stage.maxPulseTriggerRateHz = 1e3;

config.daq = struct();
config.daq.vendor = "ni";
config.daq.device = "Dev1";
config.daq.powerChannel = "ao6";
config.daq.rate = 1e6;

config.carbide = struct();
config.carbide.enabled = true;
config.carbide.ip = "192.168.11.251";
config.carbide.port = 20010;
config.carbide.timeoutSeconds = 2;
config.carbide.pollPeriodSeconds = 0.5;

config.motion = struct();
config.motion.defaultStep = struct('x', 0.01, 'y', 0.01, 'z', 0.01);
% Startup defaults for the Jog and Absolute Move controls.
config.motion.defaultManualVelocity = struct('x', 10, 'y', 10, 'z', 10);
config.motion.defaultManualAcceleration = struct('x', 100, 'y', 100, 'z', 100);
% Programmatic motion fallbacks are in mm/s and mm/s^2 respectively.
config.motion.defaultVelocity = struct('x', 100, 'y', 100, 'z', 100);
config.motion.defaultAcceleration = struct('x', 10000, 'y', 10000, 'z', 10000);
config.motion.centerPosition = struct('x', 75, 'y', 12.5, 'z', 75);
% UI/display Y is mapped as: displayY = yDisplayReference - stageY
config.motion.yDisplayReference = 25;
config.motion.travelLimits = struct( ...
    'x', [0, 150], ...
    'y', [0, 25], ...
    'z', [0, 150]);

config.execution = struct();
config.execution.pointPause = 0.1;
% Internal duration unit is seconds; the app UI displays this in us.
config.execution.pointExposureTime = 1e-6;
config.execution.streamTargetSpeed = 1.0;
config.execution.zSweepRecoveryAttempts = 3;

config.logging = struct();
config.logging.runLogFolder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'run_logs');
config.logging.progressPeriodSeconds = 1.0;

config.imaging = struct();
config.imaging.defaultZStep = 0.01;
config.imaging.defaultSettlingTime = 0.1;
config.imaging.defaultExposureUs = 5000;
config.imaging.defaultGain = 0;
config.imaging.autoExposureEnabled = true;
config.imaging.autoExposureSampleCount = 5;
config.imaging.autoExposureSafetyFactor = 0.8;
config.imaging.captureTimeoutMs = 1500;
config.imaging.captureRegion = "top-left-quarter";
config.imaging.outputFolder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', '3d_imaging');
end
