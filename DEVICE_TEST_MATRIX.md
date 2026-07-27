# KaleiDrift Device Test Matrix

Use one row per test run. Keep screen brightness consistent and remove the phone case if heat becomes unsafe.

| Device | SoC/GPU | Android | Orientation | Mode | Settled quality | Avg FPS | Worst sustained FPS | Heat after 5 min | Corridor failures | Artifacts/crashes | Notes |
|---|---|---:|---|---|---|---:|---:|---|---:|---|---|
|  |  |  | Landscape | Auto |  |  |  |  |  |  |  |
|  |  |  | Portrait | Auto |  |  |  |  |  |  |  |
|  |  |  | Landscape | Low | Low |  |  |  |  |  |  |
|  |  |  | Landscape | Medium | Medium |  |  |  |  |  |  |
|  |  |  | Landscape | High | High |  |  |  |  |  |  |

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
- Health, distance, score, throttle, and game-over actions remain readable in portrait and landscape.
