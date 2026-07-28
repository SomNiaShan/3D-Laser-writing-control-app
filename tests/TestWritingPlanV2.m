classdef TestWritingPlanV2 < matlab.unittest.TestCase
    methods (Test)
        function axisPathUsesCanonicalExecutionPlan(testCase)
            plan = localV2PathPlan(1);
            plan.source_recipe(:) = "axis_scan";
            path = localWritePlan(testCase, plan);

            trajectory = lw_import_points_table(path, false, nan);

            testCase.verifyEqual(trajectory.meta.schemaVersion, 2);
            testCase.verifyEqual(trajectory.modeSupport, "path");
            testCase.verifyEqual(trajectory.writingPlan.operation, "path");
            testCase.verifyEqual(trajectory.writingPlan.laserState, "on");
            testCase.verifyEqual(trajectory.writingPlan.x, 0);
            testCase.verifyEqual(trajectory.writingPlan.x2, 0.5);
            testCase.verifyEqual(trajectory.writingPlan.speed, 0.01);
        end

        function explicitLeadAndExitCollapseIntoOneSafeGroup(testCase)
            plan = localV2PathPlan(4);
            plan.group_id(:) = 7;
            plan.segment_index = (1:4).';
            plan.laser_state = ["off"; "on"; "on"; "off"];
            plan.x_mm = [-0.1; 0; 0.5; 1];
            plan.x2_mm = [0; 0.5; 1; 1.1];
            plan.speed_mm_s = [0.02; 0.01; 0.01; 0.02];
            plan.source_recipe(:) = "hexagon_cut";
            path = localWritePlan(testCase, plan);

            trajectory = lw_import_writing_plan_table(path);
            writingPlan = trajectory.writingPlan;

            testCase.verifyEqual(height(writingPlan), 4);
            testCase.verifyEqual(writingPlan.x, [-0.1; 0; 0.5; 1]);
            testCase.verifyEqual(writingPlan.x2, [0; 0.5; 1; 1.1]);
            testCase.verifyEqual(writingPlan.groupId, repmat(7, 4, 1));
            testCase.verifyEqual(writingPlan.segmentIndex, (1:4).');
            testCase.verifyEqual(writingPlan.laserState, ["off"; "on"; "on"; "off"]);
            testCase.verifyEqual(writingPlan.speed, [0.02; 0.01; 0.01; 0.02]);
            testCase.verifyNumElements( ...
                lw_validate_path_plan_for_run(writingPlan), 1);
        end

        function fixedPowerOverrideAppliesToV2Paths(testCase)
            plan = localV2PathPlan(1);
            plan.power(:) = 12.5;
            path = localWritePlan(testCase, plan);

            trajectory = lw_import_writing_plan_table(path, true, 37);

            testCase.verifyEqual(trajectory.power, 37);
            testCase.verifyEqual(trajectory.writingPlan.power, 37);
            testCase.verifyEqual(trajectory.meta.powerSource, "fixed_override");
        end

        function discontinuousV2GroupIsRejected(testCase)
            plan = localV2PathPlan(2);
            plan.group_id(:) = 1;
            plan.segment_index = [1; 2];
            plan.x_mm = [0; 0.6];
            plan.x2_mm = [0.5; 1];
            path = localWritePlan(testCase, plan);

            testCase.verifyError(@() lw_import_writing_plan_table(path), ...
                'lw:WritingPlanV2DiscontinuousGroup');
        end

        function pointV2PlanPreservesDwellTiming(testCase)
            plan = localV2PathPlan(2);
            plan.operation(:) = "point";
            plan.group_id(:) = nan;
            plan.segment_index(:) = nan;
            plan.laser_state(:) = "dwell";
            plan.x2_mm(:) = nan;
            plan.y2_mm(:) = nan;
            plan.z2_mm(:) = nan;
            plan.speed_mm_s(:) = nan;
            plan.dwell_s = [0.1; 0.2];
            plan.source_recipe(:) = "cartesian";
            path = localWritePlan(testCase, plan);

            trajectory = lw_import_writing_plan_table(path);

            testCase.verifyEqual( ...
                trajectory.writingPlan.operation, ["point"; "point"]);
            testCase.verifyEqual(trajectory.writingPlan.dwell, [0.1; 0.2]);
            testCase.verifyEqual(trajectory.modeSupport, "point");
        end
    end
end

function plan = localV2PathPlan(rowCount)
schemaVersion = repmat(2, rowCount, 1);
operation = repmat("path", rowCount, 1);
groupId = (1:rowCount).';
segmentIndex = ones(rowCount, 1);
laserState = repmat("on", rowCount, 1);
x = (0:rowCount - 1).' * 0.5;
y = zeros(rowCount, 1);
z = zeros(rowCount, 1);
x2 = x + 0.5;
y2 = zeros(rowCount, 1);
z2 = zeros(rowCount, 1);
speed = repmat(0.01, rowCount, 1);
power = repmat(50, rowCount, 1);
dwell = nan(rowCount, 1);
pauseSeconds = repmat(0.1, rowCount, 1);
sourceRecipe = repmat("test_path", rowCount, 1);
plan = table(schemaVersion, operation, groupId, segmentIndex, laserState, ...
    x, y, z, x2, y2, z2, speed, power, dwell, pauseSeconds, sourceRecipe, ...
    'VariableNames', {'schema_version', 'operation', 'group_id', 'segment_index', ...
    'laser_state', 'x_mm', 'y_mm', 'z_mm', 'x2_mm', 'y2_mm', 'z2_mm', ...
    'speed_mm_s', 'power', 'dwell_s', 'pause_s', 'source_recipe'});
end

function path = localWritePlan(testCase, plan)
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
path = fullfile(folder, 'writing_plan_v2.csv');
writetable(plan, path);
end
