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
| `Model` | Existing `config`, unchanged `state` struct, UI handles, prepared-plan snapshot, trajectory, progress text, run log | Hardware behavior |
| `StageLaserController` | Zaber, DAQ, manual motion, live position, laser output, manual exposure | Trajectory construction or imaging files |
| `CarbideController` | Carbide connection, polling, presets, shutter/output state | Stage motion |
| `FlirController` | FLIR connection, settings, live window, acquisition timer | 3D-stack workflow |
| `TrajectoryController` | Plan sources, import/generation, Z Sweep construction, leveling, frozen plan snapshots, and previews | Hardware execution |
| `RunController` | Prepared-plan preflight and Point/Path/Z Sweep dispatch, pause/resume, ETA and recovery | Plan construction or device protocol implementation |
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
Trajectory preview, preflight summaries, run logs, Point execution, and Path
execution must all consume that same snapshot. `meta.powerSource` is
descriptive (`plan` or `file`) and must never trigger a runtime override.

Z Sweep has no loaded trajectory and therefore owns a separate Sweep Power
parameter in its prepared-plan snapshot. Control-tab Manual Power and Exposure
Power are manual-hardware settings only.

## Prepared-plan ownership

`Model.PreparedPlan` is the execution boundary between Plan and Run. Plan
preparation freezes one `kind` (`point`, `path`, or `z_sweep`) plus all
kind-specific inputs. The Run tab derives its display and dispatcher from that
kind; it must not expose a second mode selector or reread Plan parameter fields
at Start. Any subsequent Plan edit sets `TrajectoryInputsDirty` and prevents
execution until a new snapshot is prepared.

## Writing-plan ownership

`trajectory.writingPlan` is the only internal writing-plan representation. Its
point/path operations and explicit path-segment laser states remain intact
through transforms, preview, preflight, execution, recovery, and run-log
snapshots. Historical `mode=scan|cut` columns and lead/exit columns are legal
only inside the legacy CSV import adapter and must not enter runtime state.

## Point timing ownership

Writing-plan `dwell_s` and `pause_s` values are the canonical Point timing
snapshot. Preflight resolves them into `trajectory.dwellSeconds` and
`trajectory.preWritePauseSeconds`; execution, summaries, and run-log snapshots
consume those same vectors. Plan-tab Default Dwell and Default Settle are
frozen fallbacks only for trajectories without writing-plan timing.

Positive point dwell durations must be representable by the configured Zaber
digital-output scheduler. Point exposures and the original Manual Exposure
path use one device-scheduled active-to-inactive action per exposure; the
original path performs repeat intervals on the MATLAB host. The separate
Manual Stream Exposure path stores the complete repeat sequence in one
device-side stream: each repeat has a scheduled inactive edge, while
integer-millisecond stream waits place later active edges. MATLAB only
coordinates UI and STOP after stream playback begins. Logical active/inactive
requests are mapped to electrical ON/OFF through the explicitly configured
trigger polarity.

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
4. Verify the GUI object count and normalized signature match
   `tests/TestLaserWritingAppBaseline.m`.
5. Keep behavior fixes separate from refactor-only commits.
6. Run the supervised hardware checklist before promoting this entry point.
