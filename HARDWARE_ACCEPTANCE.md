# Supervised hardware acceptance

Do not run this checklist unattended. Confirm the optical enclosure,
interlocks, sample, beam path, emergency stop, and external shutter state
before enabling any output.

## Setup

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
- Carbide: connect, poll, preset download/apply, PP divider, output enable,
  close output, standby, timer restart, disconnect, and reconnect.
- FLIR: enumerate, connect, exposure/gain, test capture, live start/stop,
  timeout handling, ROI, auto exposure, and disconnect during idle only.
- Mako: connect, monitor/alignment view, disconnect, reconnect, and app close.
- SLM: open independent control, connect batch SLM, show selected pattern,
  disconnect, and app close.

## Workflow checks

- Point Mode: import at least two point rows with different `dwell_s` and
  `pause_s` values; verify move -> pre-write settle -> exposure ordering,
  measured gate widths, start, pause before exposure, resume, STOP during a
  long dwell, zero-dwell behavior, normal finish, and error recovery. Confirm
  sub-100-us and non-100-us-multiple dwell values are rejected at preflight.
- Stream Mode: start, STOP, normal finish, trigger-rate validation, and error
  recovery.
- Cut Plan Mode: preflight, pre-write settling at each lead-in position,
  grouped execution, STOP, and output comparison.
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
