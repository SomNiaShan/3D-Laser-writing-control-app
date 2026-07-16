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

The locked GUI contract is 515 objects with normalized signature SHA-256
`cced1b618759e3bae073c3755614f07981ab4c396b9637259d8ef5427242369a`.
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

See [ARCHITECTURE.md](ARCHITECTURE.md) before changing controller ownership.
Physical-device validation remains a supervised lab step documented in
[HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md); automated tests never connect
to the stages, laser, DAQ, or cameras.
