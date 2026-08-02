# Web performance benchmark

Use this procedure before and after rendering changes. Test the deployed build; a local HTTP build is useful for iteration but is not the release result.

## Setup

1. Use a release Web export and record the commit, browser version, OS, GPU, display resolution, device-pixel ratio, and power mode.
2. Close unrelated GPU-heavy tabs and disable browser frame-rate throttling. Keep browser zoom at 100%.
3. Open browser developer tools and confirm there are no WebGL or shader errors.
4. Let each run warm up for 10 seconds, then record for 60 seconds. Do not compare editor runs with exported runs.

## Test matrix

Run every row in Chromium and Firefox at 1280×720 and fullscreen. Test both Endless and Survival with Kalei Fold, Mandelbox, Mandelbulb, Kaleidoscopic IFS, Menger Sponge, and Mixed Drift.

For the fill-rate check, repeat a fixed Kalei Fold/Endless route at manual High, Medium, and Low. These correspond to 100%, 64%, and 45% internal scale. A large FPS increase as scale falls identifies fragment/fill-rate pressure; little change points toward CPU or browser overhead.

| Commit | Browser / version | OS / GPU | Viewport | Mode | Fractal | Quality | Internal size / scale | Avg FPS | Worst sustained FPS | p90 ms | p95 ms | Console / visual notes |
|---|---|---|---|---|---|---|---|---:|---:|---:|---:|---|
|  |  |  | 1280×720 | Endless | Kalei Fold | High |  |  |  |  |  |  |
|  |  |  | 1280×720 | Endless | Kalei Fold | Medium |  |  |  |  |  |  |
|  |  |  | 1280×720 | Endless | Kalei Fold | Low |  |  |  |  |  |  |
|  |  |  | Fullscreen | Survival | Mixed Drift | Auto |  |  |  |  |  |  |

## Trace capture

- Capture a browser performance trace for one slow and one fast run. Record main-thread scripting time, rendering time, long tasks, and frame cadence.
- Use the settings diagnostics text to record resolved tier, scale, internal size, step count, p90, and p95.
- Change one rendering variable at a time. Re-run the same route after each shader or adaptive-quality change.
- Keep the single-threaded export unless traces show a CPU bottleneck that dominates frame time. Threaded Web exports require cross-origin isolation and do not reduce fragment shader cost.

## Acceptance gate

After warm-up, representative runs must sustain at least 30 FPS for 60 seconds with p95 at or below 33.3 ms, without repeated quality oscillation, shader errors, corridor failures, collision disagreement, or new visible artifacts.
