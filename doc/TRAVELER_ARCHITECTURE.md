# KaleiDrift Traveler Flight Architecture

KaleiDrift has no ship or cockpit. Flight state belongs to a camera-independent `PlayerFlightRig`; Immersive and Traveler views are presentations of that same state.

## Runtime responsibilities

```text
FlightInputAdapter -> FlightController -> TravelerSafetyController -> PlayerFlightRig
                                              |                      |
                                              v                      v
                                   SDFQueryService/WorldState   ViewModeController
                                              |                 /              \
                                   CorridorOpeningController  Immersive   Third-person
                                              |                               |
                                       FractalRenderer                  TravelerVisual
```

- `PlayerFlightRig` is authoritative for position, orientation, velocity, requested speed, and steering state.
- `FlightController` converts normalized input into desired movement. It does not know which camera or Traveler is active.
- `WorldState` contains the active seed/region/fractal, fixed structural iterations, the rendered hazard set, and current corridor deformation.
- `SDFQueryService` is the only gameplay boundary for structural and hazard clearance. Safety and cameras do not duplicate fractal formulas.
- `TravelerSafetyController` uses bounded swept-sphere and steering-biased probes, soft tangent sliding, depenetration, and last-safe recovery.
- `CorridorOpeningController` emits two risk-scaled capsule segments. Structural geometry can open; Survival hazards cannot.
- `ViewModeController` selects an Immersive rig-aligned view or an SDF-retracted third-person view without mutating the rig.
- `TravelerVisual` is cosmetic. Its scale, fragments, animation, and colors never drive gameplay.

## World consistency and quality

Structural fractal evaluation uses six iterations in every graphics preset. Adaptive quality may change render resolution, ray steps, render distance, shading detail, and post-processing, but not collision geometry. Reduced motion changes visual motion rather than moving structural surfaces.

The shader and CPU query service are paired implementations driven by the same `WorldState`. Fixed-point world-query tests protect deterministic behavior. Runtime code never reads shader state or depth back to the CPU.

Survival exposes only the same bounded sphere-hazard set to rendering and gameplay queries. Structural walls use opening and avoidance and do not cause damage; Survival sphere hazards retain health damage, invulnerability, scoring, and game-over behavior.

## Traveler resources

`resources/travelers/default_catalog.tres` contains `TravelerDefinition` resources. A definition provides its stable ID, display name, packed scene, visual scale, colors, glow, trail profile, collision radius, camera framing, and optional animation profile.

The approved collision-radius range is `0.18–0.22`; both built-in placeholders use `0.20`. Adding a Traveler requires a visual scene, definition resource, and catalog entry. It must not require changes to flight, safety, or camera code.

## Validation boundaries

Headless tests validate deterministic flight, SDF queries, prediction, corridor bounds, recovery, view invariants, camera retraction, resource fallback, and mode regressions. Transparent compositing, visual obstruction, corridor subtlety, heat, and performance still require Web/browser and physical Android validation recorded in `DEVICE_TEST_MATRIX.md`.
