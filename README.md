# KaleiDrift

**Two ways to fly through an endless fractal world on Android and the Web**

KaleiDrift is a visually reactive flight game with two complementary modes:

- **Endless:** the original calm exploration experience. The world opens around the player and has no collision punishment or fail state.
- **Survival:** free flight through the same deterministic fractal world in any direction. Walls and spatially generated obstacles remove integer health, and the run ends at zero health.

> **Development status:** Early Android rendering prototype with an additional browser preview. The current build validates the core visual approach, mobile performance, flight controls, adaptive quality, and proximity-based path opening. It is not yet the complete MVP.

## Product Vision

KaleiDrift combines free flight with an evolving psychedelic environment. Both modes allow unrestricted three-dimensional exploration. Endless is low pressure; Survival adds readable hazards, health, score, near-miss rewards, and deterministic challenge without changing the world's identity.

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
- Endless and Survival mode selection
- Deterministic open-world Survival geometry and spatial-cell obstacles shared by rendering and collision
- Five-point integer health, temporary hit invulnerability, scoring, game over, and retry
- Safe-heading spawn selection, a visible five-second spawn shield, and wall-hit rollback to recent safe space
- Fully offline procedural retro-ambient music with deterministic regional harmony
- Speed, Survival proximity, game-mode, and reduced-motion music reactivity
- Persisted procedural-music enable and volume controls
- Single-threaded browser export suitable for GitHub Pages
- Browser capability handling for SDR output, audio activation, quality defaults, and exit behavior

Not yet implemented:

- Deterministic seeded journeys and distinct procedural regions
- Smooth transitions between region palettes, geometry, fog, and audio
- Floating-origin support for effectively infinite travel
- Region caching, eviction, and deterministic regeneration
- Journey autosave, resume, and new-journey flow
- Optional phone-tilt steering and recalibration
- Steering sensitivity and independent axis inversion
- Production-ready menus, controls, and onboarding
- Additional Survival obstacle archetypes and tuned difficulty bands
- Local Survival high scores and run history

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
- A distinct Survival loop with fair, shader-matched collisions and readable damage feedback

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
- **Large centered throttle:** Forward speed
- **H:** Hide the HUD on desktop
- **Escape / Android Back:** Return to the main menu on desktop Web and Android native builds
- **Mobile Web Menu:** Return to the main menu outside fullscreen; browser/device Back exits fullscreen first
- **R:** Reset the flight on desktop

The interface scales and reflows around the device safe area in portrait and landscape.

The final MVP will also include optional phone-tilt steering, neutral-position recalibration, sensitivity adjustment, and independent horizontal and vertical inversion.

## Technology

- [Godot Engine 4](https://godotengine.org/)
- GDScript
- Godot Mobile renderer
- Godot Compatibility renderer for Web exports
- Fragment-shader ray marching
- Signed-distance-field-based fractal rendering
- Android APK/AAB export
- WebAssembly browser export

The project avoids relying on compute shaders as a core Android requirement. If the ray-marched approach cannot meet the target performance across supported devices, the planned fallback is a hybrid of lower-cost shader surfaces, instanced procedural geometry, fog, and post-processing.

## Getting Started

### Requirements

- A current stable Godot 4 release
- Matching Godot Web export templates
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

### Run in a Browser

The Web preset uses Godot's Compatibility renderer and a single-threaded WebAssembly build so it can run on ordinary static hosting, including GitHub Pages.

1. Install the Web export templates that match the project's Godot version.
2. Export the `Web` preset to an empty directory:

   ```bash
   godot --headless --rendering-method gl_compatibility --path . --export-release "Web" build/web/index.html
   ```

3. Serve the directory over HTTP; Web exports do not run correctly from a `file://` URL:

   ```bash
    python -m http.server 8000 --directory build/web
    ```

   In VS Code, run **Tasks: Run Task → Serve Web build locally**; it exports first, then serves the game at `http://localhost:8000/`.
   Use **Run and Debug → Chrome: Debug local Web build** to export, serve, and open DevTools automatically. Use **Tasks: Run Task → Run Web export validation** for the required artifact check.

4. Open `http://localhost:8000/`.

The browser build starts at Low quality when there is no saved preference, then retains the normal Automatic, Low, Medium, and High controls. Browser output is SDR because Godot's current WebGL 2 Compatibility renderer does not provide HDR output. A device may support HDR in other browser content; tone mapping and color controls remain available here in SDR, while HDR output controls are disabled. Music begins after the first keyboard, mouse, touch, or controller-button interaction because browsers require user activation for audio. Web uses a browser-native Web Audio fallback because runtime procedural audio streams are not supported reliably by the Godot Web audio path.

Current browser assumptions and limitations:

- A current browser with WebAssembly and WebGL 2 support is required.
- Chrome, Firefox, Edge, and Safari should be tested independently; GPU and shader behavior can differ.
- The build is single-threaded and does not require cross-origin-isolation headers.
- Closing the browser tab is left to the browser, so the in-game Exit button is hidden.
- Settings use Godot's browser-backed `user://` storage and are local to the site origin.

### Deploy to GitHub Pages

The `.github/workflows/deploy-web.yml` workflow checks project startup with Godot 4.7.1, creates a fresh single-threaded Compatibility Web export, verifies `index.html`, JavaScript, WASM, and PCK files, and deploys only `build/web` with the official GitHub Pages actions whenever `main` is pushed. Generated Web files stay out of source control.

In the repository's GitHub settings, set **Pages → Build and deployment → Source** to **GitHub Actions**. The export uses relative asset references, so the deployed game works at a repository URL such as `https://<owner>.github.io/KaleiDrift/`.

## Export to Android

1. Install the Godot Android build template.
2. Configure the Android SDK and JDK in Godot.
3. Open the included Android export preset.
4. Confirm that the Mobile renderer is selected.
5. Export a debug APK.
6. Install and test the APK on a physical Android phone.

Do not commit signing keys, keystores, exported APKs, AABs, or local credentials to the repository.

Do not commit generated browser exports either; the Pages workflow produces them from the current source.

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

For browser validation, test at least one Chromium browser, Firefox, Safari where available, and one mobile browser. Verify loading, resizing, pointer and touch input, both game modes, audio activation, settings persistence, SDR messaging, and browser-console output.

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
- [x] Reactive ambient audio
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

- Combat and enemies
- Missions, progression gates, and currencies
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

## Build and test foundation

KaleiDrift uses one Godot 4.7.1 project and shared gameplay code for Android, Windows, and Web. Generated output always belongs under `build/` and is not committed.

```bash
godot --headless --path . --quit-after 1
godot --headless --path . --script res://scripts/tests/adaptive_quality_test.gd
godot --headless --path . --script res://scripts/tests/survival_smoke_test.gd
godot --headless --path . --script res://scripts/tests/survival_integration_test.gd
godot --headless --path . --export-debug "Android" build/android/Kaleidrift-debug.apk
godot --headless --path . --export-debug "Windows Desktop" build/windows/Kaleidrift.exe
godot --headless --rendering-method gl_compatibility --path . --export-release "Web" build/web/index.html
```

Use [`doc/WEB_PERFORMANCE_BENCHMARK.md`](doc/WEB_PERFORMANCE_BENCHMARK.md) for repeatable Chromium and Firefox frame-time testing.

Pull requests validate startup, native smoke/integration tests, and Web/Windows exports. Pushes to `main` run `.github/workflows/deploy-web.yml`, which deploys only `build/web`; Pages must be enabled by the repository owner. Releases are created only from semantic `v*.*.*` tags and currently attach a Windows ZIP. Android signing and iOS distribution require owner-provided credentials and platform setup.

Platform capability decisions live in `scripts/platform/` and all flight input is normalized through `scripts/input/`. Test physical Android devices, Windows, and Chrome/Edge/Firefox/Safari plus a mobile browser; automation does not replace device or browser validation. See `AGENTS.md` for repository safety and definition-of-done requirements.

## License

KaleiDrift source code is licensed under the [MIT License](LICENSE).

Game artwork, music, audio, branding, promotional media, and other creative assets are not covered by the MIT License unless explicitly stated. See [ASSET_LICENSE.md](ASSET_LICENSE.md) for details.

Third-party components remain subject to their respective licenses.
