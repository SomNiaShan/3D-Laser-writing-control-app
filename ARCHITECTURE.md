# Refactored application architecture

## Isolation rule

This directory is a complete application boundary. Its launcher, GUI builders,
configuration, device services, execution functions, Mako code, SLM code,
tests, and documentation are all bundled here. Runtime code must not resolve or
add the parent directory to the MATLAB path.

`laser_writing_app_refactored()` runs this directory's `lw_setup_project()`,
constructs one `AppController`, and returns its figure. The controller is
retained in figure appdata under `LaserWritingAppController` for the lifetime
of the window. The original application remains outside this directory and is
not a runtime dependency.

## Ownership

| Component | Owns | Must not own |
| --- | --- | --- |
| `AppController` | Composition, GUI builder binding, application-level logging, Mako/SLM shell lifecycle | Run algorithms or device protocol details |
| `Model` | Existing `config`, unchanged `state` struct, UI handles, trajectory, progress text, run log | Hardware behavior |
| `StageLaserController` | Zaber, DAQ, manual motion, live position, laser output, manual exposure | Trajectory construction or imaging files |
| `CarbideController` | Carbide connection, polling, presets, shutter/output state | Stage motion |
| `FlirController` | FLIR connection, settings, live window, acquisition timer | 3D-stack workflow |
| `TrajectoryController` | Source modes, import/generation, leveling, trajectory and Z Sweep previews | Hardware execution |
| `RunController` | Preflight, Point/Stream/Cut Plan/Z Sweep orchestration, pause/resume, ETA and recovery | Device protocol implementation |
| `ImagingController` | Single/batch imaging, auto exposure, metadata/output orchestration | FLIR live-window policy |
| `UiPolicyController` | `Enable`/`Visible` policy, global status and synchronization order | Hardware writes |
| `SafetyCoordinator` | The only STOP and window-close shutdown sequence | Feature workflow decisions |

## Dependency rules

1. Controllers receive the shared `Model` plus a validated `Ports` struct.
2. Cross-controller work goes through a declared port; do not reach through
   `AppController` or add a new shared closure variable.
3. Hardware, timers, clocks, dialogs, SLM, Mako, and run executors are called
   through `Model.Services`. Add the production mapping in `defaultServices`
   and its contract in `validateServices` before using a new side effect.
4. Bundled `lw_*` execution, preflight, batch, metadata, GUI-builder, Mako,
   and SLM implementations retain their current input/output formats.
5. A controller may update its own transient model fields. Cross-domain state
   transitions belong in an explicit coordinating method.
6. GUI builders remain the source of static layout and defaults. Controllers
   bind callbacks and update transient state only.

## Power ownership

`trajectory.power` is the canonical execution-power snapshot for every loaded
plan. Runtime controllers must not replace it from an unrelated UI field.
Trajectory preview, preflight summaries, run logs, Point Mode, Stream Mode,
and Cut Plan Mode must all consume that same snapshot. `meta.powerSource` is
descriptive (`plan` or `file`) and must never trigger a runtime override.

Z Sweep has no loaded trajectory and therefore owns a separate Sweep Power
parameter. Control-tab Manual Power and Exposure Power are manual-hardware
settings only.

## Safety sequence

`SafetyCoordinator.shutdown()` is idempotent and invokes every step under an
independent exception boundary:

1. Set stop flags and clear pause/resume context.
2. Stop FLIR live view.
3. Request stage stop.
4. disable stage pulse trigger and force DAQ output to zero.
5. Stop FLIR acquisition and delete acquisition/live timers.
6. Stop position and Carbide timers.
7. Close SLM, disconnect batch SLM, and shut down Mako.
8. Finalize the run log and disconnect all hardware.
9. Delete the application figure.

Never bypass this coordinator from a STOP or close callback.

## Change checklist

Before committing a behavior-preserving change:

1. Confirm the launcher and tests do not resolve the parent project.
2. Run `run_refactor_checks()` from this directory.
3. For lifecycle or GUI work, also run with `IncludeStress=true` and
   `IncludeScreenshots=true`.
4. Verify the GUI still has 515 objects and the locked signature remains
   `cced1b618759e3bae073c3755614f07981ab4c396b9637259d8ef5427242369a`.
5. Keep behavior fixes separate from refactor-only commits.
6. Run the supervised hardware checklist before promoting this entry point.
