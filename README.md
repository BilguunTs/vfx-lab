# Spirit Forge — VFX Lab

Personal R&D playground for stylized supernatural VFX in Godot 4.6 (Forward+, GDScript).
The project brief lives in [CLAUDE.md](CLAUDE.md).

## Run

Open the folder in Godot 4.6 and press **F5**, or from a terminal (macOS):

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

On a fresh clone, open the project in the editor once (or run the same binary with
`--headless --import`) before running from the terminal. `.godot/` is not committed, and without its
global class cache scripts that use `class_name` types such as `DebugDraw` fail to parse.

The lab plays the current effect once on start.

| Key | Action |
| --- | --- |
| Space | Strike (the beater swings; the effect fires on impact). Strikes overlap — press again before one ends and both play out |
| R | Reset (clear all strikes, restore debris, normal speed, home camera) |
| D | Debug overlay: 1 m grid, origin axes, effect guides, timing readout |
| T | Toggle slow motion (0.2x) |
| L | Loop: strike every `loop_interval` seconds |
| 1–9 | Mute/unmute a layer (layered effects) |
| − / = | Weaker / stronger strike (0.25–2.0), strikes immediately |
| V | Next variation (new seeds for every layer), strikes immediately |
| A | Toggle the beater's anticipation (windup) on/off, strikes immediately |
| Right/middle drag, wheel | Orbit, zoom |
| Esc | Quit |

## Tweaking live

Run with F5, open **Remote** in the Scene dock, select a layer such as `Lab/EffectSlot/DrumStrike/PulseRing` and edit its
exported parameters in the Inspector. Press **L** so it keeps replaying while you tweak.
Remote edits are lost when the game stops — copy values you like into the scene.

## Layout

```
lab/            sandbox scene: environment, camera, controls, HUD, debug guides
experiments/    one folder per experiment, each with its own README
shared/         code reused by 2+ experiments (noise shader include, debug lines, particle layer)
docs/           EXPERIMENT_LOG.md — what was tried and learned
```

`Lab.striker` (the drum stand-in) is optional: with it, Space swings the beater and the effect
plays on its `impacted` signal; clear it to fire effects instantly.

To try another effect, replace the child of `Lab/EffectSlot`. An effect needs `play()` and
`reset()`; `set_debug(bool)`, `get_debug_text()`, `get_layer_status()` and
`toggle_layer(index)` are optional.

## Experiments

- [04 Energy Ring](experiments/04_energy_ring/README.md) — drum strike Phase A: an expanding ground ring.
- [05 Drum Strike](experiments/05_drum_strike/README.md) — layered strike: pulse ring + echo ring + dust burst + rune seal + spirit motes + debris. **Loaded in the lab.**
