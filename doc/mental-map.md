# KaleiDrift: A Plain-Language Mental Map

KaleiDrift is continuous flight through a ray-marched fractal world. Endless is relaxed exploration; Survival adds deterministic sphere hazards, health, score, near misses, and game over. There are no ships or cockpits.

## What owns the player?

`PlayerFlightRig` owns the real position, rotation, velocity, speed, and steering state. Input changes the rig through `FlightController`. Cameras only observe it.

- Immersive view places the presentation camera on the rig and shows no body or foreground Traveler.
- Traveler view follows the rig from behind and displays a cosmetic abstract Traveler.
- Switching views never changes movement.

## How the world stays traversable

`SDFQueryService` asks the same deterministic world state used by rendering for clearance. `TravelerSafetyController` samples the projected path, including steering-biased probes. When structural geometry becomes risky, a small local corridor opens; if needed, velocity slides along the surface. Outward correction and a verified last-safe transform are final recovery layers.

Survival sphere hazards are different: they are never carved away and still cause one damage event with the existing invulnerability window.

## How the screen is built

The fractal shader renders into a scaled 2D `SubViewport`. Traveler view adds a transparent, bounded 3D viewport above the fractal and below the HUD. Its camera retracts using SDF samples rather than a physics SpringArm. Immersive view disables this extra viewport.

## Important files

| Area | Files |
|---|---|
| Composition, modes, UI | `scripts/main.gd`, `main.tscn` |
| Flight authority/input | `scripts/flight/`, `scripts/input/` |
| Shared world and opening | `scripts/world/`, `scripts/gameplay/survival_world.gd` |
| Views and camera | `scripts/view/` |
| Traveler data/visuals | `scripts/travelers/`, `resources/travelers/`, `scenes/travelers/` |
| Rendering | `scripts/rendering/`, `shaders/fractal_flight.gdshader` |
| Quality/diagnostics | `scripts/performance/` |
| Settings/platform/audio | `scripts/settings/`, `scripts/platform/`, `scripts/audio/` |

## Quality and settings

Adaptive quality changes internal render scale, ray steps, view distance, and visual detail. It never changes gameplay SDF accuracy. Settings in `user://settings.cfg` include quality, fractal, comfort/audio/HDR/controller options, view mode, Traveler ID, and primary/accent colors.

Use `doc/TRAVELER_ARCHITECTURE.md` for the engineering contract and `DEVICE_TEST_MATRIX.md` for honest physical-device/browser evidence.
