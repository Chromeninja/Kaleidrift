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
