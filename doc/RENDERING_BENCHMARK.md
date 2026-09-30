# Rendered performance benchmark

Run one benchmark at a time on an otherwise idle PC. This harness requires a real display and GPU; it rejects headless execution. Keep the renderer, graphics adapter, resolution, frame count, warmup, mode, view, fractal, and power state identical when comparing changes.

```powershell
& 'D:\Code\Tools\Godot_v4.7.1-stable_win64.exe' --path . --display-driver windows --rendering-method mobile --log-file D:/Code/Kaleidrift/build/performance/high.log --script res://scripts/tests/rendering_benchmark.gd -- quality=2 view=immersive mode=endless frames=600 warmup=120 width=1280 height=720 output=res://build/performance/high
```

Arguments after `--` are `key=value`:

| Argument | Default | Meaning |
| --- | --- | --- |
| quality | 2 | 0 Low, 1 Medium, 2 High |
| view | immersive | immersive or traveler |
| mode | endless | endless or survival |
| fractal | 0 | Existing fractal selector index |
| frames | 600 | Measured frames |
| warmup | 120 | Unmeasured startup frames |
| width, height | 1280, 720 | Window dimensions |
| scenario | fixed | fixed or auto; auto feeds actual wall timing to adaptive quality |
| output | res://build/performance/run | Generated results directory |
| shader | current shader | Optional `res://` path to a saved baseline shader |
| capture_frames | 3 sparse poses | If explicitly supplied, capture this many contiguous route frames after timing; `0` disables capture |

The harness instantiates the real main scene and compiles an in-memory copy of its script that redirects settings, character profiles, and controller logs to unique files inside the output directory. It leaves the player's saved data untouched. Audio is disabled, VSync disabled, and frame rate uncapped. Main simulation is stepped once per rendered pose at 1/60 second. A precomputed 360-pose route orbits a nearby surface found using CPU SDF queries, and safe positions are precomputed outside measured work. The safety and camera logic still run for each pose. This is a repeatable rendering stress case, not a recording of the player's exact route or a free-flight gameplay benchmark.

`results.json` records monotonic wall-frame intervals, CPU time executing the main physics/process callbacks, summed viewport GPU time, quality transitions, and per-frame camera/safety timings when available. Mean, p90, p95, and maximum are reported. GPU timings come from [RenderingServer viewport measurements](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu); zero readings can mean unavailable measurements and must not be interpreted as zero GPU cost. The adapter/API metadata and engine version are included; record the installed vendor driver version separately.

Three PNG snapshots are captured after measured frames, so GPU readback and PNG encoding do not inflate timing results. Snapshot shader time and initial camera state are reset deterministically. Explicit `capture_frames=90` instead captures a contiguous 90-frame sequence with normal camera smoothing after its initial reset; encode `frame_%d.png` at 60 fps for temporal comparison. Screenshots show representative poses but cannot establish absence of temporal flicker. Capture a video of interactive reproduction separately.

Compare Low/Medium/High, Immersive/Traveler, Endless/Survival, and 1280x720 versus 640x360. For adaptive behavior, use `scenario=auto` with enough frames for the controller's real-time warmup and cooldowns (at least 30 seconds total). Report timing around recorded transitions; short fixed-quality runs cannot validate adaptive stability. Generated output stays under ignored `build/`. Browser and physical Android validation remain separate and must be recorded in `DEVICE_TEST_MATRIX.md`.
