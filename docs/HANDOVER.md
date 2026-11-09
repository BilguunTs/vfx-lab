# Handover — Spirit Forge VFX Lab

State as of 2026-11-09 (commit `b0bc65f` on `main`). For the project's goals and art direction
read [CLAUDE.md](../CLAUDE.md); for what was tried and why, [EXPERIMENT_LOG.md](EXPERIMENT_LOG.md).
Each experiment folder has its own README with parameters and things to try.

## 1. What this is

A Godot 4.6 (Forward+, GDScript) sandbox for stylized supernatural VFX. It has no gameplay,
no plugins and no external assets: every mesh, texture and shape is procedural or a primitive.
It's built around one hero moment: a shaman's drum strike that releases a spiritual pulse,
plus reusable effect components that grew out of it.

## 2. Getting started

```
# fresh clone: build the import cache once (or just open the project in the editor)
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --import
# run the main lab (drum strike)
/Applications/Godot.app/Contents/MacOS/Godot --path .
# run the ghost-wrap lab
/Applications/Godot.app/Contents/MacOS/Godot --path . res://experiments/06_ghost_wrap/ghost_wrap_lab.tscn
```

Without the import step, scripts using `class_name` types (`DebugDraw`, `GhostElement`, …)
fail to parse. `.godot/` is not committed; `.uid` files are, so keep them with their files.

The lab's controls are in the [README](../README.md#run). The ones to know first:
- **Space** strikes; **R** resets.
- **1–9** mute layers.
- **Tab** opens the live tuning panel.
- **D** debug overlay, **G** test grid, **T** slow motion.

## 3. What's done

| # | Experiment | State | Entry point |
| --- | --- | --- | --- |
| — | **Lab** (`lab/`) | Done | `lab/lab.tscn` (main scene) |
| 04 | Energy Ring | Done | Used as layers of 05 |
| 05 | Drum Strike (layered) | Done: phases A–F of the brief | Main lab |
| 06 | Ghost Wrap | Done, reusable | `ghost_wrap_lab.tscn` |
| 07 | Shockwave (air distortion) | Done, reusable | Layer 6 of 05 |
| 08 | Spirit Wisp + ghost figures | Done, reusable | Layer 8 of 05 |

What each one contains:
- **Lab:** camera, controls, HUD, debug guides, live tuning panel, procedural ground and stones.
- **Energy Ring:** an expanding ground ring with a shader band, used as layers of the drum strike.
- **Drum Strike:** a drum stand-in with beater anticipation and recoil. Each hit fires 6
  short-lived layers plus 2 long-lived ones, and rapid hits overlap.
- **Ghost Wrap:** one value dissolves any meshes into a swappable element (smoke, fire, water,
  wind) from a placeable reveal point. It has an optional smoke orb at full ghost, and fire
  accents (sparks, embers).
- **Shockwave:** an expanding sphere that bends the background outward.
- **Spirit Wisp:** steering-driven shy spirits. One wisp of light and two hooded Ghost Wrap
  figures flinch when the pulse reaches them.

**Drum strike layer keys:**

| Key | Layer | Kind |
| --- | --- | --- |
| 1 | PulseRing | per strike |
| 2 | EchoRing | per strike |
| 3 | DustBurst | per strike |
| 4 | RuneSeal | per strike |
| 5 | SpiritMotes | per strike |
| 6 | Shockwave | per strike |
| 7 | DebrisField | persistent |
| 8 | Spirits (Bold, Timid, Loner) | persistent |

**Roadmap (CLAUDE.md §8):**

| Stage | Status |
| --- | --- |
| 1–5 | Done |
| 6 (Blender assets) | Not started |
| 7 (reusable, parameter-driven) | Largely done: Ghost Wrap elements, tuning panel |
| 8 (character attachment) | Not started |
| 9 (performance) | One check done (§8 below); no on-screen profiler |
| 10 (advanced) | Started: spirit entities, distortion |

## 4. Reusable components

None of these depend on the drum. Copy the folder (plus `shared/`) and use them anywhere.

| Component | Files | How to use |
| --- | --- | --- |
| **GhostWrap** | `experiments/06_ghost_wrap/ghost_wrap.gd` (+ shaders, `ghost_element.gd`, `ghost_accent.gd`, `elements/`) | Add as a node, set `targets` (MeshInstance3Ds), drive `intensity` 0→1. Optional: `reveal_point` (any Node3D), `element` (a `GhostElement` .tres), `blob_enabled`. `clear_smoke()`, `rebuild()` after changing targets. |
| **GhostElement / GhostAccent** | same folder | Resources describing the medium (look, motion, body edge, blob) and secondary layers (sparks…). Duplicate a preset in `elements/` to make a new element. |
| **Shockwave** | `experiments/07_shockwave/` | Instance `shockwave.tscn`, call `trigger(strength)`. |
| **SpiritWisp** | `experiments/08_spirit_wisp/spirit_wisp.gd` | Instance `spirit_wisp.tscn`, set `focus` (relative point it lingers around). `startle(from_world_pos, strength)` from anything, or `add_push(pulse_node)` to flinch when a ring's front (`get_front_radius()`) reaches it. |
| **GhostSpirit** | `ghost_spirit.gd/.tscn` | A wisp whose body is a Ghost Wrap figure; fear drives the ghost value. Swap the meshes in the scene for your own figure. |
| **WispGroup** | `wisp_group.gd` | Makes several wisps act as one layer (forwards pulses, strength, debug, reset). |
| **EnergyRing** | `experiments/04_energy_ring/` | `play()`, `set_strength()`, `get_front_radius()`. |
| **ParticleLayer** | `shared/effect_components/particle_layer.gd` | Wraps a GPUParticles3D child named `Particles`: delay, burst or tapering emission, deterministic seed, debug view. |
| **DebugDraw** | `shared/debug_draw.gd` | `DebugDraw.make_view(mesh)`, `DebugDraw.circle(...)`: unlit, always-on-top debug lines. |
| **Noise include** | `shared/shaders/noise.gdshaderinc` | `hash21` (integer hash, no seams), `value_noise`. |
| **Tuning panel** | `lab/tuning_panel.gd` | Sliders for every exported ranged int/float of a layer. Any effect offering `get_tunable_layers()`, `get_tunable(name)`, `set_tuning(name, property, value)` gets it. |
| **Ground / stones / test grid** | `lab/ground.gdshader`, `lab/stone_scatter.gd`, `lab/test_pattern.gdshader` | Procedural set dressing; the grid is for judging distortion. |

## 5. Architecture and conventions

- **Lab contract.** An effect under `Lab/EffectSlot` needs `play()` and `reset()`.
  `set_debug`, `get_debug_text`, `get_layer_status`, `toggle_layer`, `strength` and
  `variation` are optional and picked up when present. Another experiment reuses the lab
  through an inherited scene that sets `effect_scene`; see `ghost_wrap_lab.tscn`.
- **Drum strike: voices and persistent layers.**
  - Every strike instantiates `drum_voice.tscn` (a *voice*), so hits overlap.
  - A voice frees itself when all its layers report `is_active() == false`.
  - Long-lived layers are children of `DrumStrike` with `add_push(pulse)`. Each new voice's
    PulseRing is handed to them.
  - Any node with `play/reset/is_active` is a layer; `drum_strike.gd` knows nothing about
    rings.
- **Live tuning.** Voices are fresh instances, so tweaks go through `set_tuning()`, are
  recorded, and are applied to every new voice. They last only for the session; use the
  panel's **Print** and paste the values into the scene.
- **Strength scaling.** Each layer decides what `strength` means. The general rule: brightness
  scales ×s, size ×s^0.6, duration ×s^0.3, so a big hit is bigger and brighter, not slower.
- **Determinism.** Every random choice uses an exported `noise_seed` / `emission_seed`, offset
  by `variation`.
- **Time.** Shaders animated by game time use a `scaled_time` uniform fed from the script,
  because the built-in `TIME` ignores `Engine.time_scale` and would break slow motion.
- **Shader warm-up.** First use of a shader stalls a frame. The shockwave and the drum
  strike's voice prototype render once, invisibly, at load.
- **Commits.** No AI co-author or attribution trailers in commit messages (the owner's
  preference).

## 6. Adding things

**A new drum-strike layer (per strike):**
1. Make a scene whose root script has `play()`, `reset()` and `is_active()`.
   `set_strength`, `set_variation`, `set_debug` and `get_debug_text` are optional.
2. Add it as a child in `experiments/05_drum_strike/drum_voice.tscn`. It gets the next mute
   key. The keys go up to 9; group layers if you need more (see `wisp_group.gd`).

**A long-lived layer:** same, plus `add_push(source)`, and add it as a child of `DrumStrike` in
`drum_strike.tscn`.

**A new Ghost Wrap element:**
1. Duplicate `experiments/06_ghost_wrap/elements/smoke.tres`.
2. Edit it in the Inspector.
3. Add it to the demo's `elements` array so **N** cycles to it.

**A new experiment:**
1. Create a folder `experiments/NN_name/` with its own README covering: what it demonstrates,
   the visual principle, parameters, how to run, what to observe, what to try next.
2. Add a line to the main README.
3. Add an entry to `EXPERIMENT_LOG.md`.

## 7. How things were validated

There's no unit test suite; validation is by running the project:
- **Headless smoke test** (parse and runtime errors):
  `Godot --headless --path . --quit-after 120 2>&1 | grep -E "ERROR|SCRIPT"`.
  The "leaked RID" lines at exit are harmless.
- **Scripted renders:** a `-s script.gd` SceneTree script loads `lab/lab.tscn`, drives it
  (`lab._strike()`, `toggle_layer`, camera `home_*` + `reset_view()`), then saves
  `root.get_texture().get_image()` after `await RenderingServer.frame_post_draw`.
  - Run with `--always-on-top`: on macOS a covered window stops drawing and the script hangs.
  - The first run after a shader change can stall while it compiles; just rerun.
- **Behaviour logs:** for motion (the wisps), printing position, speed and fear every 0.5 s
  over 20 s caught problems that stills never would.
- **Performance:** `RenderingServer.viewport_set_measure_render_time` plus frame timing, with
  vsync off. On this Mac the frame rate stays capped at 120 fps and Metal reports no GPU
  timings, so the results show "fits in 8.3 ms or not", not the headroom.

## 8. Performance notes

- At the normal camera distance everything holds 120 fps (Apple M4, 1600×900): the full scene,
  a strike's peak, the ground shader and the spirits. Render CPU is about 0.4 ms.
- **The hotspot is smoke up close.** Large soft puffs filling the screen, layered hundreds deep,
  are the cost (overdraw), not any single shader. A camera 1.6 m from a ghost figure with the
  default smoke dropped to about 40 fps. The ghost figures now use `spirit_smoke.tres`
  (180 × 0.45 m), which holds 120.
- When a real game camera exists, fade or shrink puffs near the camera.
- The shockwave costs one screen copy per frame while active, so don't stack dozens.
- Not measured: other GPUs, higher resolutions, many Ghost Wraps at once.

## 9. Known limits and open questions

**Rendering limits:**
- **Shockwave:** Godot's screen texture holds only opaque geometry, so transparent effects
  (dust, rings, smoke) aren't bent. On plain backgrounds the bend is invisible, which is why
  the ground has detail and **G** exists.
- **Ghost Wrap reveal point:** the start point is re-picked only when the value leaves 0 or 1.
  Moving it mid-transition would make the edge jump. Ghost Wrap's own README lists its other
  limits.

**Tooling limits:**
- **Tuning panel:** numeric settings with a range only (no colours or vectors). Changes last
  for the session.

**Not verified live by hand** (only through scripts and renders):
- the key presses for Ghost Wrap's elements and orb (N, B), and the wind element's whirl
- the feel of the wisps and the ghost figures in motion
- mouse use of the tuning panel
- distance shimmer of the ground detail

**Open art question:** after a strike, the drum's spirit motes and the wisp of light are both
pale dots. Should they be one family, or clearly different?

## 10. Suggested next steps

1. **Blender drum (roadmap stage 6):** replace the drum stand-in
   (`experiments/05_drum_strike/drum_stand_in.gd`) with a modelled hand drum and beater
   imported as glTF. Keep the `strike()` / `impacted` interface, so the lab doesn't change.
2. **Shaman figure (roadmap stage 8):** a simple rigged figure. The swing animation fires the
   strike (an animation event calls `strike()`), Ghost Wrap targets the figure's meshes, and
   effects attach to bones via `BoneAttachment3D`.
3. **Strike presets:** named tuned variants (whisper, summoning, banishment) switchable by key,
   building on the tuning panel's Print output.
4. **A performance HUD:** frame time and particle counts on screen, before stacking more layers.
5. **Near-camera smoke fade** in `ghost_medium.gdshaderinc`, once a gameplay camera exists.
