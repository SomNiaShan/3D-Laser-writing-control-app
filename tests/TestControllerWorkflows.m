classdef TestControllerWorkflows < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(~)
            refactorRoot = fileparts(fileparts(mfilename('fullpath')));
            projectRoot = refactorRoot;
            addpath(fullfile(projectRoot, 'scripts'));
            lw_setup_project();
        end
    end

    methods (Test)
        function generatedPlansAndPureControllerPathsWork(testCase)
            fig = laser_writing_app_refactored();
            cleanup = onCleanup(@() closeIfValid(fig));
            drawnow;
            controller = getappdata(fig, 'LaserWritingAppController');
            model = controller.Model;

            testCase.verifyClass(controller.StageLaser, 'lw.app.StageLaserController');
            testCase.verifyClass(controller.Carbide, 'lw.app.CarbideController');
            testCase.verifyClass(controller.Flir, 'lw.app.FlirController');
            testCase.verifyClass(controller.Trajectory, 'lw.app.TrajectoryController');
            testCase.verifyClass(controller.Run, 'lw.app.RunController');
            testCase.verifyClass(controller.Imaging, 'lw.app.ImagingController');
            testCase.verifyClass(controller.UiPolicy, 'lw.app.UiPolicyController');
            testCase.verifyClass(controller.Safety, 'lw.app.SafetyCoordinator');

            model.Ui.MarkTextRadio.Value = true;
            controller.Trajectory.onSourceModeChanged([], []);
            model.Ui.PlanPowerField.Value = 7;
            model.Ui.LaserPowerField.Value = 42;
            markPlan = controller.Trajectory.buildTrajectoryFromUi();
            testCase.verifyNotEmpty(markPlan.x);
            testCase.verifyEqual(numel(markPlan.x), numel(markPlan.y));
            testCase.verifyEqual(numel(markPlan.x), numel(markPlan.z));
            testCase.verifyTrue(all(isfinite([markPlan.x(:); markPlan.y(:); markPlan.z(:)])));
            testCase.verifyTrue(all(markPlan.power == 7));

            controller.Trajectory.importTrajectoryImpl();
            controller.UiPolicy.syncAll();
            testCase.verifyEqual(model.State.trajectory, model.Trajectory);
            testCase.verifyEqual(model.PreparedPlan.kind, "point");
            testCase.verifyEqual(controller.Run.selectedRunMode(), "Point Mode");
            frozenDwell = model.PreparedPlan.defaultDwellSeconds;
            model.Ui.PointExposureField.Value = ...
                model.Ui.PointExposureField.Value + 100;
            controller.Trajectory.onPlanInputChanged([], []);
            testCase.verifyTrue(model.TrajectoryInputsDirty);
            testCase.verifyEqual( ...
                model.PreparedPlan.defaultDwellSeconds, frozenDwell);
            controller.Trajectory.importTrajectoryImpl();
            testCase.verifyFalse(model.TrajectoryInputsDirty);

            model.Ui.PlanPowerField.Value = 8;
            controller.Trajectory.onPlanPowerChanged([], []);
            testCase.verifyTrue(model.TrajectoryInputsDirty);
            controller.Trajectory.importTrajectoryImpl();
            testCase.verifyFalse(model.TrajectoryInputsDirty);
            testCase.verifyTrue(all(model.Trajectory.power == 8));

            model.Ui.FrameRadio.Value = true;
            controller.Trajectory.onSourceModeChanged([], []);
            framePlan = controller.Trajectory.buildTrajectoryFromUi();
            testCase.verifyEqual(numel(framePlan.x), 36);
            testCase.verifyTrue(all(framePlan.power == model.Ui.PlanPowerField.Value));
            testCase.verifyTrue(isfield(model.Ui, 'UseFixedPowerCheckBox'));
            testCase.verifyFalse(isfield(model.Ui, 'UseImportedPowerCheckBox'));
            testCase.verifyFalse(isfield(model.Ui, 'StreamFixedPowerField'));
            testCase.verifyFalse(isfield(model.Ui, 'RunModeGroup'));
            testCase.verifyFalse(isfield(model.Ui, 'StreamModeRadio'));
            testCase.verifyTrue(isfield(model.Ui, 'ZSweepRadio'));

            pathTrajectory = lw_make_trajectory(0, 0, 0, 10, ...
                "writing_plan", "path", struct('powerSource', "file"));
            pathTrajectory.writingPlan = table( ...
                "path", 'VariableNames', {'operation'});
            pathPlan = controller.Trajectory.preparedTrajectoryPlan( ...
                pathTrajectory, "Imported Points");
            previousPlan = model.PreparedPlan;
            model.PreparedPlan = pathPlan;
            testCase.verifyEqual(pathPlan.kind, "path");
            testCase.verifyEqual(controller.Run.selectedRunMode(), "Path Plan Mode");
            model.PreparedPlan = previousPlan;

            folder = tempname;
            mkdir(folder);
            folderCleanup = onCleanup(@() rmdir(folder, 's'));
            pointsPath = fullfile(folder, 'points.csv');
            writematrix([0, 0, 0, 4; 1, 2, 3, 9], pointsPath);
            model.Ui.ImportedPointsRadio.Value = true;
            controller.Trajectory.onSourceModeChanged([], []);
            model.Ui.InputFileField.Value = pointsPath;
            model.Ui.UseFixedPowerCheckBox.Value = false;
            controller.UiPolicy.syncAll();
            testCase.verifyEqual(string(model.Ui.PlanPowerField.Enable), "off");
            controller.Trajectory.importTrajectoryImpl();
            testCase.verifyEqual(model.Trajectory.power, [4; 9]);

            model.Ui.UseFixedPowerCheckBox.Value = true;
            controller.Trajectory.onFixedPowerOverrideChanged([], []);
            testCase.verifyTrue(model.TrajectoryInputsDirty);
            testCase.verifyEqual(string(model.Ui.PlanPowerField.Enable), "on");
            model.Ui.PlanPowerField.Value = 13;
            controller.Trajectory.importTrajectoryImpl();
            testCase.verifyEqual(model.Trajectory.power, [13; 13]);
            clear folderCleanup;

            center = model.Config.motion.centerPosition;
            model.Ui.ZSweepRadio.Value = true;
            controller.Trajectory.onSourceModeChanged([], []);
            model.Ui.ZSweepMatrixCheckBox.Value = false;
            model.Ui.ZSweepXField.Value = center.x;
            model.Ui.ZSweepYField.Value = ...
                model.Config.motion.yDisplayReference - center.y;
            model.Ui.ZSweepBackField.Value = center.z - 0.01;
            model.Ui.ZSweepFrontField.Value = center.z + 0.01;
            model.Ui.ZSweepRepeatField.Value = 1;
            model.Ui.ZSweepSpeedField.Value = 1;
            model.Ui.ZSweepReturnSpeedField.Value = 1;
            preview = controller.Trajectory.buildZSweepPreviewFromUi();
            testCase.verifyFalse(preview.isMatrix);
            controller.Trajectory.prepareZSweepPlanImpl();
            testCase.verifyEqual(model.PreparedPlan.kind, "z_sweep");
            testCase.verifyEqual(controller.Run.selectedRunMode(), "Z Sweep Mode");
            frozenSweepX = model.PreparedPlan.sweep.x;
            model.Ui.ZSweepXField.Value = frozenSweepX + 0.1;
            controller.Trajectory.onZSweepPreviewChanged([], []);
            testCase.verifyTrue(model.TrajectoryInputsDirty);
            testCase.verifyEqual(model.PreparedPlan.sweep.x, frozenSweepX);
            controller.Trajectory.prepareZSweepPlanImpl();
            testCase.verifyFalse(model.TrajectoryInputsDirty);
            model.Ui.ZSweepMatrixCheckBox.Value = true;
            controller.Trajectory.onZSweepMatrixChanged([], []);
            controller.Trajectory.prepareZSweepPlanImpl();
            testCase.verifyTrue(model.PreparedPlan.isMatrix);
            testCase.verifyEqual(numel(model.PreparedPlan.sweepJobs), 9);
            testCase.verifyEqual( ...
                model.PreparedPlan.progressTotal, ...
                model.PreparedPlan.matrix.progressTotal);
            controller.UiPolicy.syncAll();

            runResult = controller.Run.makeRunResult("test");
            testCase.verifyEqual(runResult.status, "test");
            testCase.verifyEqual(runResult.returnTarget, model.State.currentPosition);
            testCase.verifyEmpty(runResult.resumeContext);
            controller.Run.startRunEtaTimer();
            testCase.verifyEqual(model.RunEtaBaselineUnits, 0);

            controller.StageLaser.refreshLivePosition();
            testCase.verifyFalse(controller.Flir.flirLive('pause'));
            testCase.verifyTrue(isnan(controller.Carbide.cachedCarbidePulseEnergyMicroJoules()));
        end
    end
end

function closeIfValid(fig)
if ~isempty(fig) && isvalid(fig)
    close(fig);
    drawnow;
end
end
