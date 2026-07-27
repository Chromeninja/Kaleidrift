# KaleiDrift

**An endless fractal flight experience for Android**

KaleiDrift is a calm, visually reactive exploration game where the player flies continuously through an effectively infinite, procedurally generated fractal world.

There are no enemies, scores, collectibles, objectives, or fail states. The experience is built around movement, color, sound, discovery, and maintaining a relaxing sense of flow.

> **Development status:** Early Android rendering prototype. The current build validates the core visual approach, mobile performance, flight controls, adaptive quality, and proximity-based path opening. It is not yet the complete MVP.

## Product Vision

KaleiDrift combines free flight with an evolving psychedelic environment. Players can travel in any direction, adjust their speed, and move through tunnels, chambers, and abstract structures without reaching a hard boundary.

When a player approaches a surface, the environment opens or deforms to preserve a traversable path. The world should remain visually interesting without becoming punitive or interrupting forward motion.

## Current Prototype

The repository currently includes the first technical prototype for the Android MVP.

Implemented or under active validation:

- Fragment-shader ray marching through an animated fractal-like signed-distance field
- Continuous forward flight
- Touch and mouse steering
- Touch throttle control
- Camera-centered corridor opening near surfaces
- Internal render-resolution scaling through a `SubViewport`
- Automatic graphics scaling
- Low, Medium, and High manual quality presets
- Portrait and landscape layout support
- Edge-to-edge Android rendering with safe-area-aware controls
- Hideable controls and performance HUD
- Reduced-motion visual option
- Live FPS, frame-time, render-resolution, and ray-step information

Not yet implemented:

- Deterministic seeded journeys and distinct procedural regions
- Smooth transitions between region palettes, geometry, fog, and audio
- Floating-origin support for effectively infinite travel
- Region caching, eviction, and deterministic regeneration
- Journey autosave, resume, and new-journey flow
- Optional phone-tilt steering and recalibration
- Steering sensitivity and independent axis inversion
- Reactive ambient audio
- Production-ready menus, controls, and onboarding

## MVP Goals

The Android MVP is intended to deliver:

- Continuous free flight through procedurally generated fractal space
- Unlimited movement in any 3D direction
- Smooth transitions between distinct visual regions
- Proximity-based surface opening with no collision punishment
- Touch steering with optional tilt controls
- Adjustable speed with continued coasting
- Local autosave with resume and new-journey options
- Reactive ambient audio generated or assembled locally
- Automatic graphics scaling with manual overrides
- Full offline play after installation
- Portrait and landscape support
- Comfort settings for sensitivity, inversion, motion, and flashing

## MVP Success Targets

| Area | Target |
|---|---|
| Platform | Android |
| Performance | Target 60 FPS on newer Android phones |
| Stability | Complete a 30-minute session without a crash, hard boundary, or unrecoverable navigation state |
| Offline support | Gameplay, generation, saves, settings, and audio work without an internet connection |
| Usability | A new player can steer and change speed using only brief control hints |
| Orientation | Controls, HUD, menus, and safe areas reflow correctly in portrait and landscape |

## Controls

The current prototype uses:

- **Drag anywhere outside the panels:** Horizontal and unlimited vertical steering
- **Large left-side throttle:** Forward speed
- **H:** Hide the HUD on desktop
- **Escape / Android Back:** Restore the HUD after it is hidden
- **R:** Reset the flight on desktop

The interface scales and reflows around the device safe area in portrait and landscape.

The final MVP will also include optional phone-tilt steering, neutral-position recalibration, sensitivity adjustment, and independent horizontal and vertical inversion.

## Technology

- [Godot Engine 4](https://godotengine.org/)
- GDScript
- Godot Mobile renderer
- Fragment-shader ray marching
- Signed-distance-field-based fractal rendering
- Android APK/AAB export

The project avoids relying on compute shaders as a core Android requirement. If the ray-marched approach cannot meet the target performance across supported devices, the planned fallback is a hybrid of lower-cost shader surfaces, instanced procedural geometry, fog, and post-processing.

## Getting Started

### Requirements

- A current stable Godot 4 release
- Godot Android build template
- Android SDK
- Supported JDK for your Godot version
- An Android device for meaningful performance testing

### Run on Desktop

1. Clone the repository:

   ```bash
   git clone https://github.com/Chromeninja/KaleiDrift.git
   ```

2. Open the cloned folder in Godot.
3. Import the project if prompted.
4. Run the main scene.
5. Use the quality controls and performance HUD to compare settings.

Desktop testing is useful for development, but Android feasibility must be judged on physical devices rather than an emulator.

## Export to Android

1. Install the Godot Android build template.
2. Configure the Android SDK and JDK in Godot.
3. Open the included Android export preset.
4. Confirm that the Mobile renderer is selected.
5. Export a debug APK.
6. Install and test the APK on a physical Android phone.

Do not commit signing keys, keystores, exported APKs, AABs, or local credentials to the repository.

## Device Testing

Test on at least:

- One newer Android phone
- One mid-range Android phone
- One lower-spec Android phone

For each device:

1. Fly for five minutes using Automatic quality.
2. Record the quality level selected by the game.
3. Test Low, Medium, and High for at least two minutes each.
4. Rotate between portrait and landscape while moving.
5. Fly directly toward multiple surfaces and verify that a path remains open.
6. Record sustained FPS, stuttering, heat, battery drain, and graphical artifacts.
7. Repeat the test with reduced motion enabled.

Suggested prototype performance bands:

- **60 FPS:** approximately 16.7 ms per frame
- **40 FPS:** approximately 25 ms per frame
- **30 FPS:** approximately 33.3 ms per frame

See [`DEVICE_TEST_MATRIX.md`](DEVICE_TEST_MATRIX.md) for structured test recording.

## Prototype Gate

The current visual approach is ready to move into broader MVP development when:

- A newer Android phone normally sustains close to 60 FPS
- A mid-range phone remains smooth at a usable preset
- A lower-spec phone remains controllable on Low without crashes or driver artifacts
- Portrait and landscape controls remain usable after rotation
- Nearby structures consistently open before becoming hard barriers
- Reduced-motion mode materially lowers visual intensity
- The best sustainable quality level still delivers the intended visual experience

If Low quality cannot remain stable on the intended minimum device, the rendering approach should be revised before building the complete world, audio, and persistence systems.

## Roadmap

### Phase 1: Technical Prototype

- [x] Ray-marched fractal rendering
- [x] Basic flight and throttle controls
- [x] Proximity-based corridor opening
- [x] Internal resolution scaling
- [x] Automatic and manual quality settings
- [x] Portrait and landscape reflow
- [x] Reduced-motion prototype
- [ ] Complete multi-device performance testing
- [ ] Refine mobile controls and HUD

### Phase 2: World Continuity

- [ ] Deterministic journey seeds
- [ ] Logical region cells
- [ ] Multiple visual region styles
- [ ] Smooth regional blending
- [ ] Bounded region cache and eviction
- [ ] Floating-origin system
- [ ] Deterministic return traversal

### Phase 3: Player Experience

- [ ] Start screen and new-journey flow
- [ ] Local autosave and resume
- [ ] Tilt steering and recalibration
- [ ] Sensitivity and inversion settings
- [ ] Reactive ambient audio
- [ ] Production-ready comfort settings
- [ ] First-time control hints

### Phase 4: MVP Validation

- [ ] Thirty-minute stability testing
- [ ] Offline and airplane-mode validation
- [ ] Save-failure and recovery testing
- [ ] Broader Android device compatibility testing
- [ ] Release-build performance profiling

## Scope

KaleiDrift's MVP intentionally excludes:

- Combat, enemies, or fail states
- Scores, collectibles, missions, and progression gates
- Achievements and leaderboards
- Accounts, cloud saves, and online services
- Multiplayer and social sharing
- Narrative content and live operations
- Monetization systems

These boundaries keep development focused on the flight experience, procedural world continuity, comfort, performance, and atmosphere.

## Contributing

KaleiDrift is currently an early private development project. Contribution guidelines, coding standards, and issue templates will be added if the project opens to outside contributors.

For now, use focused branches and commits for individual improvements, such as:

- `mobile-ui-cleanup`
- `adaptive-resolution`
- `tilt-controls`
- `seeded-regions`
- `save-system`

## License

No open-source license has been granted at this stage. Unless a license is added, the source code and assets remain all rights reserved.
