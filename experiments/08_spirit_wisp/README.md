# 08 — Spirit Wisp

**What it demonstrates:** a creature-like effect. A small, shy spirit lingers around a point,
drifts in to look, flinches away from a pulse and comes back cautiously. Its trail sheds
fragments of light.

**Visual principle:** behaviour sells a spirit more than its look. The glow is a dot and a
halo; what makes it read as *alive* is the contrast between lazy, hesitant wandering and a sharp
startle, followed by a slow, wary return.

## How it works

- **Motion** (`spirit_wisp.gd`): steers toward a desired velocity (not a spring to a target, so
  a far target never means a fast wisp) with a capped `cruise_speed`.
  - The target drifts with smooth noise around `focus` (wander).
  - It is sometimes pulled in close to `focus` (curiosity), but never inside `personal_space`.
  - Fear pushes the target out to `hide_distance` along the flee direction.
  - Slow noise sometimes nearly stops it (hesitation).
- **Fear and wariness:** a startle sets both. Fear (flee and hide) decays over `recover_time`.
  Wariness decays `wariness_length`× slower: while wary it is slower, keeps to the outer part of
  its range, wobbles and isn't curious. That is what makes the return *cautious*.
- **Startle timing:** `add_push(source)` (the drum strike's persistent-layer call, with the pulse
  ring as the source) waits until the ring's front reaches the wisp. Closer wisps flinch sooner
  and harder. `startle(from, strength)` flinches immediately, for any other caller.
- **Look:** an additive billboard glow (`wisp_head.gdshader`) that breathes and dims while
  afraid, plus a faint OmniLight on the ground beneath it.
- **Trail:** a camera-facing ribbon through the last `trail_time` seconds of positions
  (an ImmediateMesh rebuilt every frame). `wisp_trail.gdshader` breaks it into fragments by
  *distance* along the trail, so a fast flight sheds separate wisps instead of one streak.

## Run

In the drum lab (main scene) it is the `SpiritWisp` layer: watch it idle, then press Space.
**8** mutes it. **Tab** → `SpiritWisp` tunes it live (persistent layer: changes apply at once).
**D** draws its target (yellow), velocity (red when afraid, green when calm) and wander area.

## Parameters

| Parameter | Default | Effect |
| --- | --- | --- |
| `cruise_speed` | 0.8 m/s | Calm top speed |
| `wander_speed` | 0.12 | How fast its wander target drifts |
| `hesitation` | 0.6 | How often it nearly stops |
| `curiosity` | 0.5 | How often it comes in close to look |
| `personal_space` | 0.55 m | Closest it comes to the focus |
| `startle_speed` | 6 m/s | Flinch speed |
| `hide_distance` | 4.5 m | Where it hides |
| `recover_time` | 3.5 s | Fear duration |
| `wariness_length` | 3× | How much longer the cautious phase lasts |
| `brightness`, `breathing`, `fear_dim` | 1.6, 0.35, 0.6 | Glow |
| `light_energy` | 0.2 | Light pool on the ground (physical presence) |
| `trail_time`, `trail_width`, `trail_breakup` | 1.1 s, 0.06 m, 1.0 | Trail |

## What to observe

- The flinch comes a beat *after* the hit: when the wave arrives.
- The return: it hovers at a distance, then creeps in over ~8 s, slower than it ever wanders.
- The light pool on the ground: the strongest cue that it is *in* the space.

## Try next

- `trail_breakup` 0 vs 1: comet vs. shedding spirit.
- `curiosity` 0.1 vs 0.9: aloof vs. pestering.
- `wariness_length` 1 vs 5: forgets at once vs. holds a grudge.
- Several wisps with different `noise_seed`s, possibly a "braver" one that recovers faster.
