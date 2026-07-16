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
            testCase.verifyFalse(isfield(model.Ui, 'UseImportedPowerCheckBox'));
            testCase.verifyFalse(isfield(model.Ui, 'StreamFixedPowerField'));

            center = model.Config.motion.centerPosition;
            model.Ui.ZSweepModeRadio.Value = true;
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
            testCase.verifyEqual(controller.Run.selectedRunMode(), "Z Sweep Mode");
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
