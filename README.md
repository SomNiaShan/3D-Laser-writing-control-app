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

The locked GUI contract is 527 objects with normalized signature SHA-256
`d3e089b229289266edaadd6820f3094987982a03be3f877cdbb74daa53f0aa37`.
Mako device-discovery availability is normalized because it is runtime
hardware state rather than a static GUI property.

## Execution power semantics

Loaded plans carry their final execution power in `trajectory.power`; preview,
preflight, logging, and execution all use that same snapshot. Frame and Mark
Text power is set on the Plan tab. XYZ-only point files use the Plan tab's
fixed power, while XYZP and writing-plan files always use their power column.
Stream Mode accepts only plans whose stored power is constant. Sweep Power is
separate and is used only by Z Sweep Mode. Manual power fields on the Control
tab never modify a loaded plan.

## Point timing semantics

Point Mode is a timed-dwell workflow, not a single-pulse workflow. For an
imported writing plan, each `mode=point` row's `dwell_s` and `pause_s` values
are canonical: the stage moves to the point, waits for `pause_s`, and then
uses a Zaber firmware-scheduled digital-output gate for `dwell_s`. Run-tab
Default Dwell and Default Settle values are used only by trajectories that do
not contain per-row writing-plan timing.

The configured X-LDA digital output supports scheduled durations from 100 us
in 100 us increments. Positive dwell or Stream Mode gate values below 100 us,
or values that are not a multiple of 100 us, are rejected instead of rounded.
A zero point dwell is retained as an explicit no-exposure point. The trigger
polarity is safety-critical and is set explicitly by
`config.stage.pulseTriggerActiveHigh`.

Stream Mode likewise produces a timed level gate at each trajectory point.
It does not claim or guarantee one optical pulse per gate; optical pulse count
depends on the CARBIDE repetition rate and the unsynchronized gate phase.

See [ARCHITECTURE.md](ARCHITECTURE.md) before changing controller ownership.
Physical-device validation remains a supervised lab step documented in
[HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md); automated tests never connect
to the stages, laser, DAQ, or cameras.
