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

The locked GUI contract is 645 objects. Its normalized signature is recorded
in `tests/TestLaserWritingAppBaseline.m`.
Mako device-discovery availability is normalized because it is runtime
hardware state rather than a static GUI property. The `Enable` state of the
SLM tab's saved-pattern and saved-adjustment buttons is normalized for the same
reason: it depends on which files exist in `slm_control/patterns`. The
`Visible` value of UIAxes and their title text is normalized too: the app never
sets it, and it differs between otherwise identical launches.

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

## Laser gate polarity

The default is now `config.stage.pulseTriggerActiveHigh = true`: the X-stage
digital output 1 is HIGH to enable PP_EN and LOW to disable it. Manual On/Off,
Point, Path (including imported scans), Z Sweep, both Manual Exposure modes,
STOP, and shutdown use the same polarity mapping. Stage connection and
recovery explicitly write the inactive level before reporting success.

Before using this version, inhibit optical output with the independent
shutter/interlock, close the previous app, and set CARBIDE User App -> External
Control -> Trigger external -> Active high. Restart this app to load the new
configuration, then verify the electrical gate with optical output inhibited.
An already-open app retains its old configuration. Old saved plans retain
their logical on/off states and do not need their laser_state values inverted.

CARBIDE PP_EN has an internal pull-up. An open/disconnected input can therefore
enable the pulse picker in Active high mode if the other laser conditions
permit emission. Software cannot guarantee LOW during power-up, cable loss,
communication failure, or a host crash. Keep an independent shutter/interlock;
do not use PP_EN as the sole safety barrier. A polarity mismatch reverses the
meaning of the software's On and Off commands. This change has not established
or corrected the cause of the reported 62.5 ms scan gap.

See the supervised polarity transition checks in [HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md).

## Manual Exposure timing semantics

The Control tab intentionally provides two implementations using the same
fields. `Fire Exposure` preserves the original compatibility path: MATLAB
starts each firmware-timed exposure separately and performs Interval waits on
the host. UI drawing, position reads, and timer callbacks can therefore add
latency between repeats. `Fire Stream` stores the complete repeat sequence in
one Zaber device-side stream before it starts. Each repeat schedules its own
hardware-timed OFF edge; stream waits determine the next ON edge. MATLAB only
monitors progress and STOP after playback begins, so host work does not
stretch the stored ON/OFF timeline. Exposure Power is written to the DAQ once
before stream playback and remains fixed while PP_EN is gated.

For `Fire Stream` with `Repeat > 1`, `Exposure + Interval` must be at least
1 ms and an exact multiple of 1 ms, because the Zaber stream wait command uses
integer milliseconds. Exposure itself must still be a multiple of 100 us.
Values that cannot be represented exactly are rejected rather than rounded.
Buffer setup adds a variable button-to-first-light delay, but does not change
the stored ON/OFF timeline. The pulse-trigger stage must be homed and idle
before stream playback.

## FLIR capture region (ROI)

The FLIR Camera panel chooses the sensor area used by Test Capture, Live FLIR,
single 3D stacks, and batch imaging: Custom, Full sensor, or Top-left quarter.
Custom offsets and sizes are full-sensor pixels, the same values SpinView shows
under Image Format. The camera crops in hardware, so frames, TIFF stacks, and
auto-exposure scouting only contain the ROI; `metadata.csv` records the offset
and sensor size for each frame.

`Apply ROI` writes the region to the camera, snapping it to the camera's
Width/Height/Offset step sizes, and saves it to `outputs/settings/flir_roi.json`.
The last applied region is restored at the next app start; until one is saved,
`config.imaging.captureRegion` is used. Values typed but not applied are not
used, and the imaging preflight flags them. In the Live FLIR window, `Full Frame`
shows the whole sensor, `Draw ROI` lets you drag a rectangle on the current
frame (requires the Image Processing Toolbox), and `Apply ROI` uses it.

## SLM tab

The SLM tab holds the SLM control itself (Main, Global Adjustments, and
Diagnostics); there is no separate SLM window. `lw_slm_control_app()` still
opens the same control as a standalone figure without the main app. The SLM
stays connected until you press `Disconnect SLM` or close the app. To watch
the beam while adjusting the SLM, use `Pop Out View` on the Mako tab.

The control shares the main window, so its dialogs must never cover STOP: SLM
errors are non-modal, and the actions that ask for confirmation (Delete under
Saved Patterns, Save and Delete under Saved Global Adjustments, and Reset) are
refused while a run, exposure, pause, manual stage move, or manual laser output
is active. The arrow keys nudge the selected global adjustment only while the
SLM tab and its Global Adjustments page are showing; a click anywhere else ends
the selection.

3D imaging names its output and fills the SLM columns of `metadata.csv` from
the SLM tab only while the tab is connected and showing a pattern, or from the
last batch row shown on the batch SLM. Otherwise the stack is untagged and the
preflight reports no current SLM parameters.

## SLM pattern offset

`Pattern X offset px (+right)` and `Pattern Y offset px (+down)` in the SLM
tab's Global Adjustments page move the whole displayed pattern across the
panel by whole pixels, for example to keep the beam off a damaged area. The
move is applied after the lens, X/Y shift, and aperture, so the aperture moves
with the pattern and `Aperture X/Y center px` stay relative to the pattern
center. Pixels pushed past the panel edge are dropped and uncovered pixels get
zero phase. `X/Y shift 2π` is different: it adds a phase ramp that steers the
beam and does not move the pattern on the panel. Realign the beam onto the new
area first, then adjust the offset until the pattern is centered on the beam.

Global adjustment presets store the offset. App startup, `Reset`, presets saved
before the offset existed, and new batch rows use `patternOffsetXpx` and
`patternOffsetYpx` from `slm_control/config/slm_config.m`. Batch rows carry the
offset in `GlobalPatternOffsetXpx`/`GlobalPatternOffsetYpx` (whole pixels; both
can be swept), the 3D imaging preflight shows it, and `metadata.csv` records it
as `SLMGlobalPatternOffsetX_px`/`SLMGlobalPatternOffsetY_px`.

See [ARCHITECTURE.md](ARCHITECTURE.md) before changing controller ownership.
Physical-device validation remains a supervised lab step documented in
[HARDWARE_ACCEPTANCE.md](HARDWARE_ACCEPTANCE.md); automated tests never connect
to the stages, laser, DAQ, or cameras.
