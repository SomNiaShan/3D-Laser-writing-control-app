function lw_reset_fields_from_config(ui, config, defaults)
%LW_RESET_FIELDS_FROM_CONFIG Populate UI controls from app configuration.

ui.ManualStepXField.Value = config.motion.defaultStep.x;
ui.ManualStepYField.Value = config.motion.defaultStep.y;
ui.ManualStepZField.Value = config.motion.defaultStep.z;
ui.ManualVelXField.Value = config.motion.defaultManualVelocity.x;
ui.ManualVelYField.Value = config.motion.defaultManualVelocity.y;
ui.ManualVelZField.Value = config.motion.defaultManualVelocity.z;
ui.ManualAccXField.Value = config.motion.defaultManualAcceleration.x;
ui.ManualAccYField.Value = config.motion.defaultManualAcceleration.y;
ui.ManualAccZField.Value = config.motion.defaultManualAcceleration.z;

ui.TargetXField.Value = config.motion.centerPosition.x;
ui.TargetYField.Value = defaults.centerDisplayY;
ui.TargetZField.Value = config.motion.centerPosition.z;
ui.AbsoluteVelXField.Value = config.motion.defaultManualVelocity.x;
ui.AbsoluteVelYField.Value = config.motion.defaultManualVelocity.y;
ui.AbsoluteVelZField.Value = config.motion.defaultManualVelocity.z;
ui.AbsoluteAccXField.Value = config.motion.defaultManualAcceleration.x;
ui.AbsoluteAccYField.Value = config.motion.defaultManualAcceleration.y;
ui.AbsoluteAccZField.Value = config.motion.defaultManualAcceleration.z;

ui.LaserPowerField.Value = 1;
ui.CarbidePpDividerField.Value = 1;
ui.CarbidePresetDropDown.Items = {'(not loaded)'};
ui.CarbidePresetDropDown.Value = '(not loaded)';
ui.ExposureTimeField.Value = secondsToMicroseconds(config.execution.pointExposureTime);
ui.ExposureRepeatField.Value = 1;
ui.ExposureIntervalField.Value = config.execution.pointPause;
ui.PreviewPowerField.Value = 10;

ui.InputFileField.Value = '';
ui.ColumnXField.Value = '';
ui.ColumnYField.Value = '';
ui.ColumnZField.Value = '';
ui.ColumnPField.Value = '';
ui.PlanPowerField.Value = 10;
ui.StartXField.Value = 0;
ui.StartYField.Value = 0;
ui.StartZField.Value = 0;
ui.MagnificationXField.Value = 1;
ui.MagnificationYField.Value = 1;
ui.MagnificationZField.Value = 1;
ui.EnableZCompensationCheckBox.Value = false;
ui.AutoStandbyAfterRunCheckBox.Value = false;

ui.PointExposureField.Value = secondsToMicroseconds(config.execution.pointExposureTime);
ui.PointPauseField.Value = config.execution.pointPause;
ui.StreamSpeedField.Value = config.execution.streamTargetSpeed;
ui.ZSweepPowerField.Value = 10;
ui.TTLGateWidthField.Value = config.stage.ttlGateWidthUs;
ui.ZSweepXField.Value = ui.TargetXField.Value;
ui.ZSweepYField.Value = ui.TargetYField.Value;
ui.ZSweepBackField.Value = ui.TargetZField.Value;
ui.ZSweepFrontField.Value = ui.TargetZField.Value;
ui.ZSweepRepeatField.Value = 1;
ui.ZSweepSpeedField.Value = config.execution.streamTargetSpeed;
ui.ZSweepReturnSpeedField.Value = config.execution.streamTargetSpeed;
ui.ZSweepDirectionDropDown.Value = 'Back -> Front';
ui.ZSweepMatrixCheckBox.Value = false;
ui.ZSweepMatrixXParamDropDown.Value = 'Power (%)';
ui.ZSweepMatrixYParamDropDown.Value = 'Sweep Speed (mm/s)';
ui.ZSweepMatrixXValuesField.Value = '5 10 15';
ui.ZSweepMatrixYValuesField.Value = '1 2 3';
ui.ZSweepPitchXField.Value = 0.05;
ui.ZSweepPitchYField.Value = 0.05;
ui.ZSweepBlockCheckBox.Value = false;
ui.ZSweepBlockParam1DropDown.Value = 'Repeat Count';
ui.ZSweepBlockParam2DropDown.Value = 'Exposure Direction';
ui.ZSweepBlockValues1Field.Value = '10 100 1000';
ui.ZSweepBlockValues2Field.Value = 'BF,FB,Both';
ui.ZSweepBlockPitchXField.Value = 0.5;
ui.ZSweepBlockPitchYField.Value = 0.5;

ui.FlirExposureField.Value = config.imaging.defaultExposureUs;
ui.FlirGainField.Value = defaults.flirGain;
ui.ImagingAutoExposureCheckBox.Value = defaults.autoExposureEnabled;
ui.ImagingAutoExposureSamplesField.Value = defaults.autoExposureSampleCount;
ui.ImagingAutoExposureSafetyFactorField.Value = defaults.autoExposureSafetyFactor;
ui.ImagingXField.Value = config.motion.centerPosition.x;
ui.ImagingYField.Value = defaults.centerDisplayY;
ui.ImagingZStartField.Value = config.motion.centerPosition.z;
ui.ImagingZEndField.Value = config.motion.centerPosition.z + config.imaging.defaultZStep;
ui.ImagingZStepField.Value = config.imaging.defaultZStep;
ui.ImagingSettleField.Value = config.imaging.defaultSettlingTime;
ui.ImagingTimeoutField.Value = config.imaging.captureTimeoutMs;
ui.ImagingPrefixField.Value = 'beam_stack';
ui.ImagingFolderField.Value = char(config.imaging.outputFolder);
ui.BatchNameField.Value = 'slm_batch';
ui.BatchSweepBaseNameField.Value = 'beam';
ui.BatchSweepParamADropDown.Value = 'ConeAngleDeg';
ui.BatchSweepValuesAField.Value = '0.35 0.40 0.45';
ui.BatchSweepParamBDropDown.Value = 'None';
ui.BatchSweepValuesBField.Value = '';
batchSetTableData(ui.BatchSlmTable, batchDefaultTableData(1));
end
