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

## Three temperaments

The drum strike holds three wisps under a `Spirits` group (`wisp_group.gd` forwards pulses,
strength, debug and reset, so they act as one layer). Same component, different settings in
`05_drum_strike/drum_strike.tscn`:

| Spirit | Character | Key settings | Behaviour after a strike |
| --- | --- | --- | --- |
| Bold (wisp of light) | Curious, stays close | curiosity 0.85, recover 1.8 s, hides only 3 m | Flinches to ~2.5 m, back peeking within ~5 s |
| Timid (ghost figure) | Keeps its distance | preferred_distance 2 m, recover 6 s, wariness ×4, hides 7 m, dimmer, smaller | Flees to ~5 m, still edging back 20 s later |
| Loner (ghost figure) | Haunts a spot among the stones | focus (-4.6, 0.45, -3.6), slow, low, strong ground light, long trail | Last to react (when the wave reaches it, ~2 s), a small twitch |

### Ghost figures

`ghost_spirit.gd` / `.tscn` is a wisp whose body is a small hooded figure dissolved with
Ghost Wrap (experiment 06) instead of a glow. It inherits all the wisp's motion, fear and
wariness and only replaces the look:

- The figure glides along the wisp's path just above the ground, turning to face the focus.
- Fear drives the Ghost Wrap value. It rests at `rest_ghost` (0.65: hood and shoulders solid,
  the rest smoke), dissolves at `dissolve_rate` when startled, and re-forms at `reform_rate`
  once the fear fades. A badly frightened spirit stays smoke longer.
- The reveal point is the head, so a strike dissolves it feet first, head last, and it gathers
  back from the head down. (Starting the dissolve from the drum side was the first idea, but
  Ghost Wrap only re-picks its start point when leaving fully solid or fully smoke, so moving
  it from a half-dissolved rest would make the edge jump.)
- Smoke trails come from Ghost Wrap itself as the figure moves.

Smoke: `spirit_smoke.tres`, a child-sized variant of the smoke element (180 puffs of 0.45 m
instead of 360 of 0.9 m, finer density field). The default smoke dropped a close-up (camera
1.6 m from a figure) to ~40 fps through overdraw: big soft puffs filling the screen, layered
hundreds deep, behind a see-through body. The spirit smoke holds 120 fps there (M4, capped).

A group of spirits with different characters is more unsettling than one: the scene has
*social* behaviour. `preferred_distance` keeps a wisp out of the near zone unless curiosity
wins.

## Run

In the drum lab (main scene) they are the `Spirits` layer: watch them idle, then press Space.
**8** mutes all three. **Tab** → `Spirits/Bold` (or Timid, Loner) tunes one live (persistent
layer: changes apply at once). **D** draws each wisp's target (yellow), velocity (red when
afraid, green when calm) and wander area.

## Parameters

| Parameter | Default | Effect |
| --- | --- | --- |
| `cruise_speed` | 0.8 m/s | Calm top speed |
| `wander_speed` | 0.12 | How fast its wander target drifts |
| `hesitation` | 0.6 | How often it nearly stops |
| `curiosity` | 0.5 | How often it comes in close to look |
| `personal_space` | 0.55 m | Closest it comes to the focus |
| `preferred_distance` | 0 | Distance it keeps when not curious |
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
- A fourth temperament: one *drawn* to the strike (comes closer when the drum sounds).
- Ghost figures: `rest_ghost` 0.4 vs 0.85 (almost a person vs. almost gone); a fire element on
  one of them.
- The drum's spirit motes and the wisps are both pale dots after a strike; decide whether they
  should look like one family or be clearly different.
