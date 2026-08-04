# Repository Guidelines

## Project Structure & Module Organization

KaleiDrift is a Godot 4.7.1 fractal-flight prototype targeting Android, Windows, and Web. `main.tscn` starts `scripts/main.gd`; authoritative flight/safety lives in `scripts/flight/`, shared SDF/deformation state in `scripts/world/`, cameras in `scripts/view/`, Traveler data in `scripts/travelers/` and `resources/travelers/`, Survival logic in `scripts/gameplay/`, and GPU ray marching in `shaders/fractal_flight.gdshader`. Preserve both modes, deterministic world calculations, adaptive quality, browser audio activation, and localized corridor opening. Do not reintroduce ships, cockpits, camera-owned movement, or decorative-geometry collision.

Treat `.godot/` and `build/` as generated state. Do not commit builds, APKs, PCKs, ZIPs, signing material, SDK paths, or credentials. Do not rewrite Git history, change repository visibility, enable Pages, publish releases, push tags, or change the Android package identity without owner authorization. Never claim physical-device testing that was not performed.

## Build, Test, and Development Commands

Run these from the repository root with a current Godot 4 installation:

```bash
godot --editor --path .
godot --path .
godot --headless --path . --quit-after 1
godot --headless --path . --script res://scripts/tests/survival_smoke_test.gd
godot --headless --path . --script res://scripts/tests/survival_integration_test.gd
godot --headless --path . --script res://scripts/tests/traveler_architecture_test.gd
godot --headless --path . --script res://scripts/tests/world_query_test.gd
godot --headless --path . --script res://scripts/tests/traveler_integration_test.gd
godot --headless --path . --export-debug "Android" build/android/Kaleidrift-debug.apk
godot --headless --path . --export-debug "Windows Desktop" build/windows/Kaleidrift.exe
godot --headless --rendering-method gl_compatibility --path . --export-release "Web" build/web/index.html
```

The headless launch is a quick import and startup check. Android export requires matching templates, an Android SDK, and a compatible JDK. iOS is a retained future placeholder; do not implement it without macOS/Xcode work.

Web deployment is handled only by `.github/workflows/deploy-web.yml`. It exports `Web` to `build/web/index.html`, verifies its HTML/JavaScript/WASM/PCK artifact, and uploads only `build/web`; never deploy the repository root or commit generated output.

## Coding Style & Naming Conventions

Follow existing Godot conventions: tabs for GDScript indentation, `snake_case` for variables and functions, `PascalCase` for engine types, and `UPPER_SNAKE_CASE` for constants. Add return and parameter types where practical. Keep callbacks named `_on_<source>_<event>` and private helpers prefixed with `_`.

Use Godot shader style in `.gdshader` files and descriptive `snake_case` uniforms. Prefer editor-supported changes for `project.godot` and `export_presets.cfg`; avoid unrelated generated-file churn.

## Testing Guidelines

Run the headless startup check and relevant native smoke/integration scripts before submitting. Add regression tests for deterministic logic, settings, platform decisions, input normalization, view invariants, SDF safety, and resource fallback. Collision/query accuracy must remain independent of graphics quality. Before release, exercise steering, throttle, both views, both Travelers, camera retraction, reset, quality selection, reduced motion, browser audio, resize/fullscreen, and both modes. For rendering/UI changes, test portrait and landscape on physical Android hardware and record performance, heat, artifacts, crashes, camera/corridor failures, and Immersive-versus-Traveler cost in `DEVICE_TEST_MATRIX.md`; emulators are not sufficient for performance claims.

## Commit & Pull Request Guidelines

Recent commits use short, imperative subjects such as `Update README...` and `Refactor project name...`. Keep each commit focused and explain user-visible or performance effects in the body when needed.

Pull requests should summarize the change, list validation performed and devices used, and link relevant issues. Include screenshots or recordings for visual/UI changes and before/after FPS or frame-time data for shader and quality changes. Never include APKs, keystores, SDK paths, or credentials.
