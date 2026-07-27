# Phyco Fractal Flight — Android Rendering Prototype

This Godot project is the first technical gate from the Phyco Game Android MVP PRD. It is intentionally a benchmark, not the full MVP.

## What this prototype validates

- Fragment-shader ray marching through an animated fractal-like signed-distance field
- Continuous forward flight with touch/mouse steering and throttle control
- A camera-centered carved corridor so nearby structures open before contact
- Actual internal render-resolution scaling through a `SubViewport`
- Automatic quality changes with Low, Medium, and High manual overrides
- Portrait and landscape reflow
- A reduced-motion option that limits shader animation
- Live FPS, frame-time, render-resolution, and ray-step display

It does not yet implement seeded region generation, persistence, tilt steering, reactive audio, floating origin, or production-ready controls. Those remain behind the visual-feasibility and device-performance gates.

## Recommended engine version

Use a current stable Godot 4 release with the Mobile renderer. The project is configured for Godot 4.4-compatible features and should be opened once in your installed stable editor before export so Godot can apply any current project-format migrations.

## Run on desktop

1. Open this folder in Godot.
2. Import the project.
3. Run the main scene.
4. Drag the circular joystick on the lower right to steer.
5. Use the throttle on the left to adjust speed.
6. Compare Auto, Low, Medium, and High while watching frame time.

Keyboard helpers:

- `H`: hide the HUD
- `R`: reset the flight

On Android, tap the upper-left corner while the HUD is hidden to restore it.

The Android export uses immersive edge-to-edge rendering. The fractal fills the
physical window while the HUD and touch controls are inset to the device's
reported safe area. Low and Medium render below native resolution; High renders
the fractal at the full current window resolution.

## Export to Android

1. Install Godot's Android build template and the Android SDK/JDK required by your Godot version.
2. In Godot, create an Android export preset.
3. Use a temporary debug package identifier such as `com.rileygarrett.phyco.prototype`.
4. Keep the Mobile renderer selected.
5. Export a debug APK and test it directly on physical phones.

Do not judge Android feasibility from desktop performance or an emulator.

## Device test procedure

Run the same path and settings on at least:

1. A newer Android phone
2. A mid-range Android phone
3. A lower-spec Android phone

For each phone:

- Start with Auto quality and fly for five minutes.
- Record the quality level Auto settles on.
- Run Low, Medium, and High for two minutes each.
- Rotate once in each direction while moving.
- Fly directly toward several surfaces and confirm the corridor remains open.
- Note sustained FPS, visible stutter, heat, battery drain, and any graphical artifacts.
- Repeat once with reduced motion enabled.

## Pass criteria for this gate

- Newer phone: normally sustains close to 60 FPS without frequent quality oscillation.
- Mid-range phone: remains smooth at a usable preset, preferably 45–60 FPS.
- Lower-spec phone: remains controllable at Low without crashes or driver artifacts.
- No hard wall collision occurs during ordinary forward flight.
- Portrait and landscape remain usable after rotation.
- Visual quality at the best sustainable preset is strong enough to justify continuing with ray marching.

## Likely tuning points

The most expensive variables are:

- Internal render scale
- Maximum ray-march steps
- Fractal fold iterations
- Maximum view distance
- Normal estimation on surface hits

If High is too expensive but Medium is viable, continue with the shader approach and tune. If Low cannot remain stable on the intended minimum device, use the PRD's hybrid fallback before building production systems.
