# Standalone refactored laser-writing app

This directory is a self-contained copy of the refactored MATLAB application.
It bundles its own GUI builders, configuration, hardware services, execution
code, Mako integration, and SLM integration. Runtime startup does not load any
file from the original application outside this directory.

## Start the standalone app

Open MATLAB in this directory, or add only this directory to the MATLAB path:

```matlab
appRoot = 'C:\path\to\3D_Laser_Writing';
addpath(appRoot);
fig = laser_writing_app_refactored();
```

The original `laser_writing_app.m` remains outside this directory as a separate
fallback application. It is not bundled or called by the refactored launcher.

## Directory layout

- `laser_writing_app_refactored.m`: thin standalone entry point
- `src/+lw/+app/`: refactored application controllers and model
- `src/`: bundled hardware, execution, trajectory, imaging, UI, and utilities
- `app/`: bundled Mako camera application
- `config/`: bundled hardware and application defaults
- `slm_control/`: bundled SLM application and support code
- `scripts/`: standalone MATLAB path setup
- `tests/`: no-hardware regression, isolation, lifecycle, and GUI tests

## Validation

Run the standard no-hardware checks from this directory:

```matlab
report = run_refactor_checks();
```

Run lifecycle stress and the locked screenshot comparison with:

```matlab
report = run_refactor_checks(IncludeStress=true, IncludeScreenshots=true);
```

The locked GUI contract is 514 objects. Its normalized signature is recorded
in `tests/TestLaserWritingAppBaseline.m`.
Mako device-discovery availability is normalized because it is runtime
hardware state rather than a static GUI property.

## Plan-driven execution

The Plan tab is the only place that chooses and prepares work. Imported,
generated, and writing-plan files become a frozen Point or Path plan based on
their contents. Z Sweep is a Plan source with its single-sweep, matrix, and
block parameters beside the shared preview.

The Run tab has no mode selector and does not rebuild work from live parameter
fields. It reports the prepared plan type and readiness, performs preflight,
then dispatches Point, Path, or Z Sweep execution from the frozen plan
snapshot. Editing a Plan input marks that snapshot stale and disables Start
until the plan is prepared again.

## Execution power semantics

Loaded plans carry their final execution power in `trajectory.power`; preview,
preflight, logging, and execution all use that same snapshot. Frame and Mark
Text power is set on the Plan tab. Imported points and writing plans use their
file power by default. When `Use Fixed Power (%)` is selected before import,
every imported operation instead uses the adjacent fixed power value. Sweep
Power is separate and is frozen into a Z Sweep plan. Manual power fields on
the Control tab never modify a prepared plan.

Writing-plan v2 files use `operation=point|path`. Path files contain explicit
laser-on and laser-off segments grouped by `group_id`. Generation, placement,
leveling, preview, preflight, execution, recovery, and logging all retain that
same canonical segment table in `trajectory.writingPlan`; there is no separate
scan or cut execution representation. A former axis scan is simply one
laser-on path segment, while approach and departure motion are ordinary
laser-off segments. Legacy `mode=point|scan|cut` files remain supported only
at the import boundary, where they are converted immediately to the v2 model.

## Point timing semantics

Point Mode is a timed-dwell workflow, not a single-pulse workflow. For an
imported writing plan, each `operation=point` row's `dwell_s` and `pause_s` values
are canonical: the stage moves to the point, waits for `pause_s`, and then
uses a Zaber firmware-scheduled digital-output gate for `dwell_s`. Plan-tab
Default Dwell and Default Settle values are frozen into Point plans only when
their source does not contain per-row writing-plan timing.

The configured X-LDA digital output supports scheduled durations from 100 us
in 100 us increments. Positive dwell values below 100 us, or values that are
not a multiple of 100 us, are rejected instead of rounded.
A zero point dwell is retained as an explicit no-exposure point. The trigger
polarity is safety-critical and is set explicitly by
`config.stage.pulseTriggerActiveHigh`.

See [ARCHITECTURE.md](ARCHITECTURE.md) before changing controller ownership.
Physical-device validation remains a supervised lab step documented in
[HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md); automated tests never connect
to the stages, laser, DAQ, or cameras.
