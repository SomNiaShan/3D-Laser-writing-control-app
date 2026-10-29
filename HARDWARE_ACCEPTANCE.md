# Supervised hardware acceptance

Do not run this checklist unattended. Confirm the optical enclosure,
interlocks, sample, beam path, emergency stop, and external shutter state
before enabling any output.

## Setup

- Polarity transition: inhibit optical output with the independent shutter or
  interlock before closing an old app or changing either side's polarity.
  This app now defaults to HIGH = PP_EN enabled, LOW = PP_EN disabled;
  CARBIDE External Control must use Trigger external -> Active high. Restart
  the app after changing the configuration. Do not run an old active-low app
  against the new laser setting.
- With optical output inhibited, verify X-stage digital output 1 is LOW after
  connection/reconnection, idle Off, STOP, normal finish, and app close. Verify
  HIGH only for requested exposure windows in Manual On/Off, Point, Path,
  Z Sweep, Fire Exposure, and Fire Stream. Check scheduled falling edges as
  well as the opening rising edge.
- CARBIDE PP_EN has an internal pull-up: an open signal cable can request
  emission in Active high mode. Verify independent shutter/interlock behavior
  for power-up and loss of signal/control with optical output inhibited. A
  successful software OFF test does not establish safety under these failures.
- Reference: CARBIDE-CB3-40W-CBM03-2H-3H User Manual, sections 5.8.1 and 6.3
  (pages 72 and 95), and the [Zaber X-LDA-AE I/O manual](https://www.zaber.com/manuals/X-LDA-AE#Digital_Outputs).

- Record MATLAB version, Git commit, Windows build, device serial numbers, and
  operator name.
- Start the original app once and record expected connection/status text.
- Start `laser_writing_app_refactored()` and verify the same defaults, tabs,
  labels, limits, and output directories.
- Confirm the physical laser remains off and NI DAQ output reads zero before
  connecting stages or cameras.

## Device checks

- Zaber: connect, home, live position, absolute move, every jog direction,
  bounds rejection, stop during motion, disconnect, and reconnect.
- Zaber timing: with the laser disabled or disconnected from PP_EN, probe
  device 01 (X-LDA150A-AE53D12) D12 pin 1 relative to pin 4. Confirm configured
  inactive level, active level, a requested 100 us scheduled gate, actual gate
  width, and repeated-gate jitter. Confirm Zaber and CARBIDE grounds are common.
- NI DAQ / laser: connect, laser on/off indication, one supervised manual
  exposure, STOP during exposure, and measured zero output after STOP.
- `Fire Stream` (laser disabled or disconnected from PP_EN): home the
  pulse-trigger stage, request Exposure = 1 s, Interval = 1 s, Repeat = 2, and
  scope D12 pin 1 relative to pin 4. Confirm edges at 0/1/2/3 s relative to the
  first edge: active 1 s, inactive 1 s, active 1 s. Repeat at least 20 times and
  record pulse-width, gap, and start-to-start jitter. Treat button-to-first-edge
  buffer preparation latency as a separate measurement. Run the same fields
  once with `Fire Exposure` and retain the trace as the compatibility-path
  comparison.
- Manual Exposure stream boundaries: verify 100 us Exposure + 900 us Interval
  repeats correctly; verify 100 us Exposure + 100 ms Interval is rejected
  before any pulse because the 100.1 ms cycle is not exactly representable by
  the stream wait. Confirm the DAQ power voltage is constant during a valid
  sequence.
- Manual Exposure STOP: press STOP during buffer preparation, during an active
  pulse, and during an interval. Confirm no later repeat starts, the stream is
  no longer busy, PP_EN is inactive, and DAQ measures zero. Repeat once using
  window close. A failure of any one of these checks blocks use with the laser.
- Carbide: connect, poll, preset download/apply, PP divider, output enable,
  close output, standby, timer restart, disconnect, and reconnect.
- FLIR: enumerate, connect, exposure/gain, test capture, live start/stop,
  timeout handling, ROI, auto exposure, and disconnect during idle only.
- FLIR ROI: apply a Custom ROI that SpinView also accepts (for example
  500 x 500 at 1996, 686) and confirm Test Capture returns that size and the
  same scene region. Apply Full sensor, Top-left quarter, and Custom while Live
  FLIR runs; live must resume each time. In Live FLIR, Draw ROI on a full frame,
  move and resize the rectangle, Apply ROI, and confirm the new live frame shows
  the boxed region. Press Esc while drawing and Cancel after drawing; the
  applied ROI must not change. Restart the app and confirm the last applied ROI
  is restored, then run a short 3D stack and check the preflight ROI line and
  the `OffsetX`/`OffsetY` columns in `metadata.csv`.
- Mako: connect, monitor/alignment view, disconnect, reconnect, and app close.
- SLM: in the SLM tab connect, show a pattern, disconnect, and close the app
  while connected (the HOLOEYE SLM display window must close). Connect batch
  SLM, show the selected row, and disconnect. With a pattern shown, select a
  global adjustment and nudge it with the arrow keys; then click the main Log
  and press the arrow keys, and switch to another tab and press them: the SLM
  must not change. During a run, a manual stage move, and with the laser on,
  the SLM actions that ask for confirmation (Saved Patterns Delete, Saved Global
  Adjustments Save/Delete, Reset) must refuse with a non-modal message while
  STOP stays clickable.
- SLM pattern offset: set Pattern X/Y offset in the SLM tab and confirm in the
  SDK preview that +X moves the pattern right, +Y moves it down, and the
  aperture moves with it. Show a batch row with the same offsets and confirm
  the same placement. Run a short 3D stack and check the preflight SLM line and
  the `SLMGlobalPatternOffsetX_px`/`SLMGlobalPatternOffsetY_px` metadata columns.

## Workflow checks

- Point Mode: import at least two point rows with different `dwell_s` and
  `pause_s` values; verify move -> pre-write settle -> exposure ordering,
  measured gate widths, start, pause before exposure, resume, STOP during a
  long dwell, zero-dwell behavior, normal finish, and error recovery. Confirm
  sub-100-us and non-100-us-multiple dwell values are rejected at preflight.
- Path Plan Mode: preflight, settling at each group start, explicit
  laser-on/off segment execution, pause/resume by group, STOP, and output
  comparison.
- Z Sweep: single and matrix previews, start, pause, resume, STOP, Zaber
  reconnect recovery, and return-position behavior.
- Single imaging: capture stack, auto exposure, STOP during move/settle/capture,
  TIFF and CSV metadata comparison.
- Batch imaging: SLM generation/show, capture, STOP, output folder, filenames,
  TIFF pages, CSV rows, and batch status comparison.

## Mandatory STOP/close observations

Exercise STOP and window close while idle, moving, exposing, paused, FLIR live,
auto exposing, single imaging, and batch imaging. For every case verify:

- The stage stop request is observed.
- Stage pulse triggering is disabled.
- NI DAQ output is physically measured at zero.
- FLIR acquisition and all application timers stop.
- SLM/Mako close without preventing later cleanup.
- The run log is finalized and no figure, timer, listener, camera, or hardware
  handle remains.

Any discrepancy blocks promotion of the refactored entry point. Record it as a
separate behavior defect; do not silently fix it inside a refactor commit.
