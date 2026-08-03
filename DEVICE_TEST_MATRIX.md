# KaleiDrift Device Test Matrix

Use one row per test run. Keep screen brightness consistent and remove the phone case if heat becomes unsafe.

| Device | SoC/GPU | Android | Orientation | Mode | Settled quality | Avg FPS | Worst sustained FPS | Heat after 5 min | Corridor failures | Artifacts/crashes | Notes |
|---|---|---:|---|---|---|---:|---:|---|---:|---|---|
|  |  |  | Landscape | Auto |  |  |  |  |  |  |  |
|  |  |  | Portrait | Auto |  |  |  |  |  |  |  |
|  |  |  | Landscape | Low | Low |  |  |  |  |  |  |
|  |  |  | Landscape | Medium | Medium |  |  |  |  |  |  |
|  |  |  | Landscape | High | High |  |  |  |  |  |  |

## HDR and color validation

Record these checks only on displays and operating-system modes that were directly tested. Do not infer display HDR from internal HDR rendering or from an HDR request alone.

| Device / display | OS HDR mode | Renderer | Reported / effective headroom | Game HDR status | SDR/HDR | True black | Near-black detail | Rich color / hue stability | Highlight rolloff | Banding / clipping | Screenshot / notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |  |  |  |  |

With Performance diagnostics enabled, verify the overlay remains visible in both gameplay modes, its frame graph advances without sustained allocation growth, portrait layout avoids gameplay controls, and all reported HDR states match the Settings explanation.

## Web browser test matrix

Use the deployed GitHub Pages URL for final results. A local HTTP server is suitable for development checks but does not replace the deployed-path test.

| Device / OS | Browser and version | Orientation / viewport | Mode | Quality / scale | Avg FPS | Worst sustained FPS | p90 ms | p95 ms | Audio after first input | Fullscreen | Menu / safe area | Settings persist | Shader artifacts | Console errors / notes |
|---|---|---|---|---|---:|---:|---:|---:|---|---|---|---|---|---|
| Desktop | Chrome / Edge | 1280×720 | Endless | Auto |  |  |  |  |  |  |  |  |  |  |
| Desktop | Firefox | 1280×720 | Survival | Auto |  |  |  |  |  |  |  |  |  |  |
| macOS / iOS | Safari | Landscape | Endless | Low |  |  |  |  |  |  |  |  |  |  |
| Mobile | Chrome or Safari | Portrait | Survival | Low |  |  |  |  |  |  |  |  |  |  |

For each browser, verify:

- The loading screen completes at the repository Pages path, not only at a domain root.
- Mouse drag, touch drag, throttle, keyboard reset, and HUD controls respond where available.
- Endless and Survival start, run, and return to the menu correctly: Android uses native Back, desktop Web uses Escape, and mobile Web uses the in-flight Menu button outside fullscreen.
- The web fullscreen button enters and exits fullscreen when supported, updates its icon, and fails gracefully when the browser denies or lacks the API.
- Automatic, Low, Medium, and High quality selections resize the internal render target.
- Reduced motion changes the visual response.
- Music remains silent before browser activation, begins after the first interaction, and responds to its toggle and volume.
- HDR output controls are disabled and the settings screen explains that Godot's WebGL renderer outputs SDR without claiming the device lacks HDR capability.
- Settings survive a reload on the same site origin.
- Window resizing and portrait/landscape changes preserve readable controls and reported safe areas.
- The browser console contains no uncaught errors, shader compilation failures, or missing-file requests.

## Decision after testing

- **Proceed with ray marching:** Newer and mid-range phones meet the gate at acceptable quality.
- **Proceed with a split renderer:** Retain ray marching on capable devices and use a hybrid fallback on constrained devices.
- **Pause and redesign:** Low quality fails on the minimum supported device or produces unacceptable driver artifacts.

## Survival validation

Record Endless and Survival as separate rows for every device. For Survival, also verify:

- One impact removes exactly one health point.
- A single overlap cannot drain multiple points during the invulnerability window.
- Survival starts facing the safest sampled route and displays a five-second shield countdown.
- A wall hit restores the player to recent safe space and provides enough shield time to turn away.
- Visible tunnel boundaries and obstacle surfaces agree with collision.
- Survival retains the chambers, openings, gyroid structures, regional color, and visual complexity of Endless.
- Thin obstacles cannot be crossed without collision at maximum throttle.
- Every generated section contains a passable route.
- Players can turn, reverse, branch, and revisit space without being pulled back to a course centerline.
- Returning to a previously visited 3D cell regenerates the same obstacle layout.
- Damage flash and vibration remain comfortable with reduced motion enabled.
- Health pips, health text, shield countdown, distance, score, throttle, platform-appropriate navigation, and game-over actions remain readable in portrait and landscape.
