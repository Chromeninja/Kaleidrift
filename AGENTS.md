# Repository Guidelines

## Project Structure & Module Organization

KaleiDrift is a Godot 4 Android prototype. `project.godot` defines the project and input actions, while `main.tscn` is the entry scene. Runtime behavior and dynamically built UI live in `scripts/main.gd`. GPU ray-marching logic belongs in `shaders/fractal_flight.gdshader`. Android packaging settings are stored in `export_presets.cfg`, and device results should be recorded in `DEVICE_TEST_MATRIX.md`.

Treat `.godot/` as generated editor state. Do not commit builds from `Exports/`, Android packages, or signing material.

## Build, Test, and Development Commands

Run these from the repository root with a current Godot 4 installation:

```bash
godot --editor --path .
godot --path .
godot --headless --path . --quit-after 1
godot --headless --path . --export-debug "Android" Exports/Kalei-Test.apk
```

The first command opens the editor; the second runs `main.tscn`. The headless launch is a quick import and startup check. The export command builds the configured debug APK and requires Godot Android templates, an Android SDK, and a compatible JDK.

## Coding Style & Naming Conventions

Follow existing Godot conventions: tabs for GDScript indentation, `snake_case` for variables and functions, `PascalCase` for engine types, and `UPPER_SNAKE_CASE` for constants. Add return and parameter types where practical. Keep callbacks named `_on_<source>_<event>` and private helpers prefixed with `_`.

Use Godot shader style in `.gdshader` files and descriptive `snake_case` uniforms. Prefer editor-supported changes for `project.godot` and `export_presets.cfg`; avoid unrelated generated-file churn.

## Testing Guidelines

There is no automated test framework or coverage threshold. Before submitting, run the headless startup check and exercise steering, throttle, HUD hiding, reset, quality selection, and reduced motion. For rendering or UI changes, test portrait and landscape on a physical Android device. Record performance, heat, artifacts, crashes, and corridor failures in `DEVICE_TEST_MATRIX.md`; emulators are not sufficient for performance claims.

## Commit & Pull Request Guidelines

Recent commits use short, imperative subjects such as `Update README...` and `Refactor project name...`. Keep each commit focused and explain user-visible or performance effects in the body when needed.

Pull requests should summarize the change, list validation performed and devices used, and link relevant issues. Include screenshots or recordings for visual/UI changes and before/after FPS or frame-time data for shader and quality changes. Never include APKs, keystores, SDK paths, or credentials.
