# KaleiDrift: A Plain-Language Mental Map

This guide explains how KaleiDrift works for someone who may not be comfortable with game code yet. It is meant to answer two questions:

1. What does the player experience?
2. Where should I look when I want to change something?

## The short version

KaleiDrift is currently a small Godot prototype. The player is always moving forward through a glowing, abstract world. The player changes direction by dragging and changes speed with the throttle. There are no enemies, goals, points, collectibles, collisions, or game-over screen.

The game is made from three important pieces:

```text
project.godot  ->  tells Godot how to start and render the project
main.tscn      ->  starts the Main object
scripts/main.gd -> runs the game, builds the controls, moves the camera
shaders/fractal_flight.gdshader -> draws the world one screen pixel at a time
```

The scene file is intentionally tiny. Almost everything visible is created by `main.gd` when the game starts.

## What happens when the game starts

The sequence is:

1. Godot reads `project.godot` and opens `main.tscn`.
2. `main.tscn` creates one `Main` node using `scripts/main.gd`.
3. `_ready()` loads saved settings.
4. `_build_render_pipeline()` creates the off-screen drawing area and connects the shader to it.
5. `_build_hud()` creates the menu, throttle, settings controls, and performance text.
6. The current quality and HDR/color settings are sent to the shader.
7. The game begins in the menu. Press Play to hide the interface and start flying.

The important startup function is `_ready()` in `scripts/main.gd`.

## What the player sees

### Main menu

The menu is built in `_build_menu_panel()`. It contains:

- Play: hides the menu and enters flight.
- Settings: opens the quality, motion, and HDR/color settings.
- Exit: exits where the platform allows it.
- A status message.
- Performance information while the game is running.

The interface has two states:

- `MENU`: controls are visible and flight input is ignored when it lands on a control.
- `PLAYING`: the menu is hidden and dragging steers the camera.

The functions `_start_playing()`, `_show_main_menu()`, `_show_settings()`, and `_handle_back_command()` switch between these states.

### Flight controls

- Drag anywhere outside a control to look left, right, up, or down.
- Use the centered vertical throttle to change forward speed.
- Press `H` on desktop to toggle between the game and the menu.
- Press `Escape` or Android Back to return to the menu.
- Press `R` on desktop to reset position, direction, and speed.

Touch and mouse input are handled in `_input()`. The actual steering change is calculated in `_apply_steering_delta()`.

The player does not physically move a 3D aircraft. Instead, the code moves an imaginary camera through the shader world. This is why the experience feels like flight even though the scene contains no 3D meshes.

## The game loop: what happens every frame

`_process(delta)` runs once per rendered frame.

It does four main jobs:

1. Adds time to `elapsed`.
2. Converts `yaw` and `pitch` into a forward, right, and up direction.
3. Moves `camera_position` forward using `speed`.
4. Sends camera, time, quality, and display information to the shader and updates the performance HUD.

The central movement idea is:

```text
new camera position = old camera position + forward direction × speed × frame time
```

Because movement uses frame time, the flight should remain approximately the same speed on fast and slow devices.

## How the world is drawn

The file `shaders/fractal_flight.gdshader` does not use regular 3D objects. It uses a technique called ray marching. A simple explanation:

1. Start at the camera.
2. Shoot an imaginary ray through each screen pixel.
3. Ask the world how far that ray is from the nearest surface.
4. Move forward by that safe distance.
5. Stop when the ray reaches a surface or the viewing distance is exhausted.
6. Color the surface, add fog and glow, and write the final pixel.

The shader's `fragment()` function performs this process for every pixel.

### The shape of the world

`world_sdf(point)` describes the world as a distance field. It combines:

- A repeating gyroid-like pattern.
- A folded fractal pattern from `fractal_fold(point)`.
- Slow spatial waves that vary the shape.

The shader does not store a map of rooms. It calculates the shape from the position being inspected. This makes the world feel endless and keeps the project small, but it also means the current prototype does not yet have saved, deterministic regions or a true world map.

### Why the player does not get stuck

`world_sdf()` creates a short, forward-facing capsule only when the signed-distance field directly ahead is close to a surface. This keeps the route safe without continuously hollowing out the scene. The important settings are:

- `safe_radius`: how wide the protected space is.
- `corridor_start`: the short lead-in before the protected space begins.
- `corridor_length`: how far ahead the protected space extends once it is needed.
- `corridor_trigger_distance`: how close the forward path must be before the opening fades in.
- `camera_position` and `camera_forward`: where the corridor starts and which way it points.

This is the prototype's proximity-based path opening. It is not collision handling: the shader changes the visible distance field so a route remains open.

### Color, regions, and atmosphere

`region_color()` creates color using palette math, surface direction, and travel distance. The world changes color gradually based on the Z position. These are visual bands, not separate saved game regions yet.

The shader also adds:

- A dark gradient background.
- Fog with distance.
- Small star-like points.
- A soft glow near surfaces.
- Tone mapping and color gamut adjustment.

Reduced motion changes the fractal's animation so its rotating/flickering movement is less intense. The setting is passed from GDScript to the shader through the `reduced_motion` uniform.

## Quality and performance

The three quality presets live near the top of `scripts/main.gd`:

| Preset | Internal render scale | Ray steps | Fractal detail | View distance |
|---|---:|---:|---:|---:|
| Low | 45% | 44 | 3 | 46 |
| Medium | 64% | 64 | 4 | 62 |
| High | 100% | 84 | 5 | 78 |

The internal render scale means the shader may draw a smaller image and then stretch it to the screen. This is usually the biggest performance lever.

`_apply_quality()` sends the preset values to the shader. `_resize_render_target()` changes the size of the off-screen image.

Automatic quality checks recent frame times in `_evaluate_automatic_quality()`:

- If the recent 90th-percentile frame time is too slow, quality drops one level.
- If it stays comfortably fast for long enough, quality rises one level.
- The game checks approximately every two seconds.

The performance HUD is updated by `_update_metrics()`. It shows FPS, frame time, pass/over-target status, quality, render size, and ray-step count.

## How the screen is assembled

`_build_render_pipeline()` creates this chain:

```text
Shader -> ColorRect inside SubViewport -> TextureRect filling the screen -> player sees it
```

The `SubViewport` is the smaller internal canvas used for quality scaling. The `TextureRect` displays that canvas at the actual window size.

The HUD is a separate `CanvasLayer`, so controls and labels appear over the shader image. `_update_safe_layout()` keeps controls away from phone notches and system areas, and adapts sizes for portrait and landscape.

## Settings that are saved

Settings are saved with Godot's `ConfigFile` to `user://settings.cfg`. This is a per-device user-data location, not a file in the repository.

Saved settings currently include:

- Quality preset.
- Automatic quality on/off.
- Reduced motion.
- HDR mode.
- Tone mapping mode.
- Reference white and peak brightness limit.
- Highlight and color-gamut intensity.

`_load_settings()` reads them during startup. `_save_settings()` writes them whenever a relevant control changes.

There is not yet a journey save, resume system, seed, or persistent flight location. Adding those would be a separate feature from the existing settings file.

## HDR and color controls

HDR handling is split between GDScript and the shader:

- GDScript decides whether the renderer and device can use HDR.
- GDScript sends the selected color values to the shader.
- The shader applies gamut adjustment in `apply_gamut()`.
- The shader applies tone mapping in `apply_tone_map()`.

The intended safe place to change the user-facing HDR controls is the settings UI and its callback functions in `main.gd`. Change the actual visual response in the corresponding shader functions.

## Where to make common changes

### Change movement feel

Look in `scripts/main.gd`:

- Starting position, direction, and speed: variables near the top and `_reset_flight()`.
- Forward movement: `_process()`.
- Drag sensitivity: `_apply_steering_delta()`.
- Speed limits and slider behavior: `_build_throttle()` and `_on_speed_changed()`.

### Change the appearance of the world

Look in `shaders/fractal_flight.gdshader`:

- Main shapes: `fractal_fold()` and `world_sdf()`.
- Corridor opening: `safe_radius`, `corridor_length`, and the capsule inside `world_sdf()`.
- Colors: `region_color()` and `palette()`.
- Fog, stars, and glow: the lower part of `fragment()`.
- HDR/tone mapping: `apply_gamut()` and `apply_tone_map()`.

### Change the menus or controls

Look in `scripts/main.gd`:

- Overall UI creation: `_build_hud()`.
- Throttle: `_build_throttle()`.
- Main/settings menu: `_build_menu_panel()`.
- Orientation and safe-area layout: `_update_safe_layout()`.
- Menu transitions: `_start_playing()`, `_show_main_menu()`, and `_show_settings()`.

### Change quality behavior

Start with `QUALITY_PRESETS`, then inspect `_apply_quality()`, `_resize_render_target()`, and `_evaluate_automatic_quality()`.

Remember that increasing render scale, ray steps, detail iterations, or view distance generally costs performance.

### Change keyboard shortcuts

The action names and key assignments are in `project.godot` under `[input]`. The response to those actions is in `_input()`.

## A safe way to modify the project

For a small change, follow this path:

1. Decide whether the change is about movement/UI/settings or the visual world.
2. Start in `scripts/main.gd` for movement/UI/settings; start in the shader for visuals.
3. Find the named function in the “Where to make common changes” section.
4. Make one focused change.
5. Run the headless startup check:

   ```text
   godot --headless --path . --quit-after 1
   ```

6. Run the game and test the behavior in both portrait and landscape where relevant.
7. For visual or performance changes, test on a physical Android device and record the result in `DEVICE_TEST_MATRIX.md`.

Avoid editing `.godot/`, exported APKs, signing files, or generated import data. Do not treat the shader as a normal GDScript file: shader syntax and available functions are different.

## Current prototype versus future game

Implemented in the current code:

- Continuous forward flight.
- Mouse and touch steering.
- Throttle control.
- Procedural fractal/gyroid-style visuals.
- Corridor opening near surfaces.
- Low, Medium, High, and automatic quality behavior.
- Portrait/landscape-safe UI layout.
- Reduced motion.
- Performance HUD.
- Saved display and quality settings.

Planned but not implemented yet:

- True seeded journeys and distinct world regions.
- Floating origin for very long travel.
- Region caching and deterministic return travel.
- Journey autosave, resume, and new-journey flow.
- Phone-tilt steering.
- Reactive ambient audio.
- Production onboarding and comfort settings.

If a feature appears in the README roadmap but not in the files described here, assume it is a plan rather than working code.

## File map

| File | Plain-language responsibility |
|---|---|
| `project.godot` | Project name, starting scene, mobile renderer, window/orientation, keyboard actions |
| `main.tscn` | Minimal entry scene that starts `Main` |
| `scripts/main.gd` | Game loop, camera flight, input, menus, settings, quality, layout, HUD |
| `shaders/fractal_flight.gdshader` | Procedural world shape, ray marching, color, fog, glow, tone mapping |
| `export_presets.cfg` | Android export/package settings |
| `DEVICE_TEST_MATRIX.md` | Physical-device test results and performance decisions |
| `README.md` | Product vision, setup, roadmap, and testing expectations |
| `.godot/` | Generated Godot editor/import state; do not hand-edit or commit changes |

## One mental model to keep

The game has two cooperating halves:

```text
GDScript is the pilot and stage manager:
movement, input, menus, settings, quality, layout, timing

Shader is the dream:
the endless shapes, colors, fog, stars, glow, and open corridor
```

When the player changes speed or direction, GDScript updates the camera information. The shader uses that information to draw what the player sees next.
