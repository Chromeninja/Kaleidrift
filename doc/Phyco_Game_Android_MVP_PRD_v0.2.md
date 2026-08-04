# Phyco Game — Android MVP PRD

> **KaleiDrift mode amendment:** The product now contains two explicit open-world modes. Endless retains every no-collision requirement in this document. Survival preserves unrestricted flight in any 3D direction while adding deterministic spatial obstacles, five integer health points, wall and obstacle damage, temporary hit invulnerability, and a game-over/retry flow. Requirements that prohibit collision punishment apply to Endless only.

> **Traveler architecture amendment:** The player is now a camera-independent flight rig with Immersive and third-person Traveler presentations; ships and cockpit views are excluded. Structural fractal walls use predictive opening, sliding, and recovery without damage in both modes. Survival's deterministic sphere hazards retain damage, health, invulnerability, scoring, and game over. This amendment supersedes earlier wall-damage language.

**Product:** Infinite Fractal Flight Experience  
**Version:** 0.2  
**Date:** July 25, 2026  
**Status:** Discovery complete; ready for technical prototype

# 1. Product Vision

Create a calm, visually striking Android experience in which the player continuously flies through an effectively infinite, procedurally generated fractal world. The experience combines relaxation, visual discovery, and free exploration without scores, collectibles, combat, fail states, or walls.

The world should feel navigable but never punitive. Structures can form tunnels, chambers, and surfaces, yet they morph open as the player approaches so forward motion and the flow state are preserved.

# 2. MVP Outcome and Success Definition

The MVP succeeds when a player can install the game on a supported Android device, begin a new exploration, steer intuitively in any direction, vary speed, cross smoothly between distinct visual regions, and continue indefinitely without encountering a hard boundary or requiring an internet connection.

| **Measure**       | **MVP target**                                                                        |
|-------------------|---------------------------------------------------------------------------------------|
| Core experience   | Continuous free flight through procedurally generated fractal space                   |
| Performance       | Target 60 FPS on newer Android phones; adapt quality to protect smooth play           |
| Session stability | No crash, hard boundary, or unrecoverable navigation state during a 30-minute test    |
| Offline behavior  | All core gameplay, generation, settings, and audio work after installation            |
| Usability         | A new player can steer and change speed without a tutorial beyond brief control hints |

# 3. Target Platform and Presentation

| **ID**  | **Requirement**                        | **Acceptance condition**                                                                                                           |
|---------|----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| PLAT-01 | Android is the only MVP platform.      | A release build installs and launches on the defined test-device set.                                                              |
| PLAT-02 | Support portrait and landscape.        | The viewport, HUD, joystick, throttle, menus, and safe areas reflow correctly after rotation.                                      |
| PLAT-03 | Work fully offline after installation. | Airplane-mode testing supports new explorations, audio, settings, and procedural generation.                                        |
| PLAT-04 | Target 60 FPS on newer phones.         | A representative modern device sustains the target during normal traversal; automatic scaling reacts before play becomes unstable. |

# 4. Core Gameplay

| **ID**  | **Requirement**                  | **MVP behavior**                                                                                           |
|---------|----------------------------------|------------------------------------------------------------------------------------------------------------|
| GAME-01 | Continuous flight                | The player coasts forward by default and may adjust horizontal direction, vertical direction, and speed.   |
| GAME-02 | Unlimited direction              | In both Endless and Survival, the player may turn, reverse, and travel in any 3D direction without a prescribed course. |
| GAME-03 | No walls or collision punishment in Endless | Nearby surfaces deform or open a traversable corridor before contact.                              |
| GAME-04 | Hybrid environment               | Recognizable tunnels and structures remain navigable while surfaces morph in response to proximity.        |
| GAME-05 | Pure exploration                 | No collectibles, score, enemies, objectives, progression gates, or lose condition.                         |
| GAME-06 | Distinct regions                 | Visual regions use different forms and color systems, with smooth transitions rather than loading screens. |
| GAME-07 | Distinct Survival mode           | Mode selection clearly separates relaxing Endless flight from health-based Survival runs.                   |
| GAME-08 | Fair Survival collision          | The static gyroid field uses matching deterministic equations for collision and rendering in every direction. |
| GAME-09 | Integer health                   | Survival starts at five health; one accepted wall or obstacle impact removes one point.                     |
| GAME-10 | Spawn and hit recovery           | Survival chooses a clear initial heading, grants a visible five-second spawn shield, and restores wall impacts to a recent safe position with a shorter recovery shield. |
| GAME-11 | Survival game over               | Zero health stops the run and presents distance, score, retry, and mode-selection actions.                   |

# 5. Controls and Comfort

## 5.1 Default Touch Controls

The default layout places a virtual joystick on the right for horizontal and vertical steering and a throttle control on the left for speed. Controls must scale and reposition for portrait, landscape, display cutouts, and system gesture areas. Coasting continues when the player releases steering input.

## 5.2 Alternate Control Mode

Phone-tilt steering is an optional mode. The player can recalibrate the neutral pose without restarting a journey. Throttle remains touch-controlled unless later usability testing supports a better alternative.

| **ID**  | **Setting**             | **Required behavior**                                                                                         |
|---------|-------------------------|---------------------------------------------------------------------------------------------------------------|
| CTRL-01 | Control visibility      | Controls and HUD can be hidden and restored without leaving the journey.                                      |
| CTRL-02 | Sensitivity             | A user-adjustable steering sensitivity setting applies to touch and tilt input.                               |
| CTRL-03 | Inversion               | Horizontal and vertical steering inversion are independently configurable.                                    |
| CTRL-04 | Reduced motion/flashing | A comfort option reduces rapid color cycling, pulse intensity, camera effects, and abrupt visual transitions. |
| CTRL-05 | Orientation transition  | Active inputs safely reset during rotation to prevent an unintended turn or speed change.                     |

# 6. Procedural World Model

The world is deterministic from a journey seed. Space is divided into logical region cells used to select fractal parameters, palettes, structure tendencies, and audio states. The renderer blends neighboring cell parameters so region boundaries are not visible.

Only a bounded neighborhood around the player remains in the runtime cache. Cells beyond the configured eviction radius are discarded. If the player returns during the active session, the same cell is regenerated from its seed rather than permanently stored. Closing the game discards the active exploration state.

| **ID**   | **Requirement**                | **Implementation intent**                                                                                                            |
|----------|--------------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| WORLD-01 | Effectively infinite traversal | Use deterministic coordinates, a floating-origin strategy, and regenerable cells to avoid finite map boundaries and precision drift. |
| WORLD-02 | Bounded memory                 | Keep only nearby cell descriptors and necessary visual resources; evict distant data asynchronously.                                 |
| WORLD-03 | Smooth regional change         | Blend geometry/fractal parameters, color palettes, fog, and audio across a transition band.                                          |
| WORLD-04 | Proximity opening              | Deform the signed-distance field or equivalent surface representation around the player to maintain a safe corridor.                 |
| WORLD-05 | Session determinism            | A seed reproduces consistent region characteristics while the exploration is active; no journey state is retained after termination. |
| WORLD-06 | Shared visual identity         | Survival uses the same complex field and regional color language as Endless without a linear tunnel or prescribed route. |
| WORLD-07 | Spatial Survival hazards       | Nearby hazards derive from deterministic 3D world cells and regenerate consistently when the player returns. |

# 7. Audio

The MVP uses a reactive ambient soundtrack generated or assembled locally. Audio responds smoothly to speed, proximity to surfaces, visual-region parameters, and transition intensity. Changes must be gradual and should support the meditative experience rather than signal objectives.

| **State input**     | **Audio response**                                                          |
|---------------------|-----------------------------------------------------------------------------|
| Speed               | Adjust energy, layer density, or filter openness without changing abruptly. |
| Surface proximity   | Add restrained spatial texture or resonance as structures approach.         |
| Region identity     | Blend region-specific tonal palettes or stems during biome transitions.     |
| Reduced-motion mode | Reduce sharp transients and tightly synchronized flashing/audio pulses.     |

# 8. Main Menu and Session Behavior

The game opens at a minimal main menu. Selecting **Play Now** always creates a fresh exploration with a new journey seed. There is no Continue, Load, autosave, cloud save, or journey recovery. Closing the game discards the active exploration state and any runtime world cache.

Settings persist locally because they are player preferences rather than journey state. If the app enters the background and Android keeps its process alive, the current session may remain available when the player returns. If Android closes the process, the next launch begins a new exploration.

| **ID**  | **Requirement** | **Acceptance condition** |
|---------|-----------------|--------------------------|
| MENU-01 | Minimal main menu | The main menu provides **Play Now**, **Settings**, and **Credits**. |
| SESS-01 | Fresh exploration | Selecting **Play Now** creates a new seed and starts a new exploration. |
| SESS-02 | No journey persistence | Closing or terminating the app does not retain player position, direction, speed, seed, region state, or runtime cells. |
| SESS-03 | Preference persistence | Graphics, control, comfort, and audio preferences remain available after relaunch. |
| SESS-04 | Background behavior | The current session may continue only while the operating system retains the app process; otherwise relaunch begins fresh. |

# 9. Graphics Quality Management

Automatic quality scaling is enabled by default and targets smooth frame pacing. The player may override the automatic selection with manual presets. The system should adjust expensive rendering variables incrementally rather than switching the entire visual identity.

| **Adjustable variable**          | **Automatic behavior**                               | **Manual exposure**        |
|----------------------------------|------------------------------------------------------|----------------------------|
| Internal render resolution       | Primary scaling lever based on sustained frame time  | Low / Medium / High preset |
| Ray-march or surface step budget | Reduce iterations before severe frame loss           | Mapped to quality preset   |
| Shadow/occlusion detail          | Reduce or disable on constrained devices             | Mapped to quality preset   |
| Post-processing and glow         | Reduce intensity/resolution while preserving palette | Mapped to quality preset   |
| World detail distance            | Reduce distant complexity before nearby navigability | Mapped to quality preset   |

Automatic scaling should use hysteresis and a short evaluation window to prevent visible quality oscillation. The player can restore Automatic at any time. Settings persist locally.

# 10. Recommended Technical Direction

Use Godot 4 with GDScript for the MVP shell, input, settings, region management, UI, and reactive audio. Use the Mobile renderer and implement the core fractal view primarily as a fragment-shader ray-marched signed-distance field or a closely related shader technique. This approach is more appropriate than generating and storing dense fractal meshes for every nearby cell.

Avoid making compute shaders a core dependency for the Android MVP. Godot's documentation warns that compute-shader support is generally poor on mobile because of driver issues, while the Mobile renderer is designed around mobile GPU constraints. A fragment-shader path also makes dynamic quality scaling through render resolution and iteration counts straightforward.

The first technical prototype must validate the visual technique on real Android hardware before production architecture is finalized. If acceptable image quality cannot reach the performance target, the fallback is a hybrid of lower-cost shader surfaces, instanced procedural geometry, fog, and post-processing rather than abandoning Godot immediately.

# 11. MVP Scope Boundaries

| **Included in MVP**                                                                         | **Explicitly deferred**                                               |
|---------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| Infinite seeded journey; touch and tilt controls; both orientations; reactive ambient audio | Collectibles, scoring, missions, achievements, unlocks, leaderboards  |
| Fresh exploration on every Play Now; automatic quality scaling with override                 | Journey saves, Continue/Load, autosave, accounts, cloud saves, online services, multiplayer, social sharing |
| Hideable HUD; sensitivity; inversion; reduced-motion/flashing mode                          | Screenshot mode, photo tools, replay, user-authored worlds            |
| Smooth visual regions and proximity-based surface opening                                   | Large biome catalog, narrative content, monetization, live operations |

# 12. Prototype Gates Before Design Production

| **Gate**            | **Evidence required to proceed**                                                                            |
|---------------------|-------------------------------------------------------------------------------------------------------------|
| Visual feasibility  | One navigable fractal region with proximity opening and no visible wall collisions.                         |
| Device performance  | On-device frame-time captures across at least one newer, one mid-range, and one lower-spec Android phone.   |
| Control usability   | Touch joystick/throttle and tilt steering remain understandable in portrait and landscape.                  |
| Comfort             | Reduced-motion/flashing mode materially lowers pulse rate and camera/transition intensity.                  |
| World continuity    | Travel across multiple seeded regions, evict prior cells, reverse course, and regenerate them consistently. |
| Session lifecycle   | Confirm Play Now always starts fresh and app termination discards journey state while preferences persist.     |

# 13. Proposed Engineering Defaults for the Prototype

These are starting values for measurement, not locked product decisions. Use logical region cells approximately 128–256 world units wide, retain the current cell plus a two-cell neighborhood in each direction, begin opening the safe corridor before the camera reaches a surface, and test automatic scaling around 16.7 ms, 25 ms, and 33.3 ms frame-time bands. Final values must come from device profiling and playtesting.

# 14. Source Notes

**Reference experience:** https://www.youtube.com/watch?v=R2PiVXjanws

**Godot renderer overview:** https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html

**Godot compute-shader mobile warning:** https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html

**Godot multiple resolutions and sensor orientation:** https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html

**Godot Android export guidance:** https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
