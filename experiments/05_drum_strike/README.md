# 05 — Drum Strike (layered)

**What it demonstrates:** the drum strike built as independent layers under one trigger.
Currently: `PulseRing` (the main ring from experiment 04), `EchoRing` (a fainter, delayed copy)
`DustBurst` (Phase B: ground dust kicked out by the strike), `RuneSeal` (Phase C: a circle
of glyphs that ignites, cools and burns away), `SpiritMotes` (Phase E: the residue), `Shockwave` (air distortion from experiment 07),
`DebrisField` (Phase D: stone shards the pulse kicks as it passes) and `Spirits`
(experiment 08: three wisps with different temperaments that flinch when the pulse reaches them).

**Full timeline:** impact 0–0.3 s (rings, dust, seal ignition) → decay 0.3–2.4 s (echo, seal
cools and burns) → aftermath 0.5–5.3 s (motes rise and fade).

**Strikes overlap.** Each hit spawns its own copy of the strike and earlier ones play out
underneath, so rapid hits stack into concentric ripples and a re-ignited, brighter seal —
nothing is cut off or reset. Mashing Space queues beats on the drum (one every ~0.35 s).

**Visual principle:** layering beats brightness. A second, weaker wave ~0.1 s behind the first
adds weight and a sense of resonance (the drum skin still vibrating) without making anything
brighter. Because the echo is slower to die than the pulse, the effect *decays in two steps*
instead of switching off.

## How it works

- **Voices.** `drum_voice.tscn` holds the per-strike layers (PulseRing, EchoRing, DustBurst,
  RuneSeal, SpiritMotes, Shockwave). Every `DrumStrike.play()` instantiates a fresh voice, applies
  strength / variation / mutes / debug to it, and plays it. A voice frees itself once all its
  layers report `is_active() == false` (~5 s).
- **Persistent layers** are `DrumStrike`'s own children (`DebrisField`, `Spirits`). They exist once;
  each new voice's PulseRing is handed to them via `add_push()`.
- **Live tuning** (Tab in the lab): voices are fresh instances, so tweaks go through
  `set_tuning(layer, property, value)`, are recorded, and applied to every new voice.
  `get_tunable(layer)` returns a template voice kept out of the tree (persistent layers are
  tuned directly). Lasts for the session; use the panel's Print to keep values.
- `drum_strike.gd` knows nothing about rings — any voice child with `play()`, `reset()` and
  `is_active()` is a layer.
- Each layer owns its timing. The echo is the same `energy_ring.tscn` with overrides in
  `drum_voice.tscn`: `start_delay` 0.12 s, longer `lifetime`, smaller `max_radius`, thinner,
  softer, dimmer, cooler `color`, different `noise_seed` (so its wobble doesn't match the pulse).

## Important parameters (on `EchoRing`)

| Parameter | Value | Why |
| --- | --- | --- |
| `start_delay` | 0.12 s | Under ~0.05 s it merges into the pulse; over ~0.25 s it reads as a second strike |
| `intensity` | 1.1 | Roughly at the glow threshold — present but never competing with the pulse |
| `lifetime` / `max_radius` | 1.6 s / 3.4 m | Travels slower and less far, so it feels like a weaker aftershock |
| `color` | darker, cooler | Separates the layers without adding a new hue |

## DustBurst (Phase B)

**Principle: energy vs. matter.** The rings are emissive, fast and additive; the dust is lit,
dark-ish, alpha-blended, heavier and slower. It launches with the impact but stays well behind
the ring front, then lifts and billows as it slows. That contrast is what gives the strike
physical presence — not the particle count (only 64).

`dust_burst.tscn` (script: `shared/effect_components/particle_layer.gd`) → `Particles` (GPUParticles3D, one-shot, `explosiveness` 0.92) → Process Material:

| Parameter | Value | Why |
| --- | --- | --- |
| `emission_shape` Ring, radius 0.25–0.4 | | Dust starts at the drum's footprint, not a single point |
| `radial_velocity` 4–8 + `radial_velocity_curve` | decays 1 → 0.25 by 40 % life | Outward push that dies quickly: launch then drift (same ease-out idea as the ring) |
| `initial_velocity` 0.4–1.4, `direction` up, `spread` 30° | | Gentle lift so the dust billows instead of sliding flat |
| `gravity` −0.6, `damping` 0.3–0.8 | | Floaty, heavy-air dust — not debris |
| `scale_curve` 0.5 → 1.5 | | Puffs expand as they disperse |
| `color_ramp` | fast fade-in, slow fade-out, warm grey → neutral | Dust appears instantly and settles slowly |

Draw pass: a QuadMesh with a lit `StandardMaterial3D` (billboard particles, `proximity_fade` so
puffs don't cut hard into the floor). The soft round sprite is a `GradientTexture2D` (radial fill)
— no image file. `burst_seed` + `use_fixed_seed` make every replay identical.

Debug (**D**) swaps the puffs for small orange markers so you can see each particle's position and spread.

## RuneSeal (Phase C)

**Principle: stillness against motion.** Everything else rushes outward; the seal stays put
around the drum, so the eye has something to rest on — that is where the "ancient / ritual"
read comes from. Its life is a small anticipation-impact-decay arc of its own: the pulse front
*writes* the glyphs into the ground as it passes (inner end first, strokes flaring white-hot
just behind the front), they cool from ember to dark red, then burn away through a noise
dissolve with a hot edge — they end as embers rather than fading out.

**Cause and effect between layers.** `RuneSeal.ignition_source` points at `PulseRing`, which
exposes `get_front_radius()`. The seal's front only ever grows, so it stays lit after the ring
fades. If the source is empty or muted (press **1**), the seal falls back to sweeping its own
front over `ignite_time` — compare the two: with the ring it reads as *caused*, alone it reads
as *decorative*.

**Glyphs are invented, not real script.** Each glyph is a spine pointing away from the centre
with up to four slanted side strokes, picked by hashing the glyph index. The vertical spine
echoes the structure of Mongolian script without imitating actual letters (which would be both
inaccurate and disrespectful as decoration). Change `noise_seed` for a different "alphabet".

**Colour:** warm ember against the cool jade rings — fire and spirit, two hues total. Set
`hot_color` / `cool_color` to jade tones if you prefer a single-hue palette; compare both.

| Parameter | Default | Effect |
| --- | --- | --- |
| `inner_radius` / `outer_radius` | 0.85 / 1.45 m | Glyph band |
| `glyph_count`, `stroke_width` | 14, 0.04 m | Density and weight of the glyphs |
| `ignition_source` | `../PulseRing` | Layer whose front ignites the seal |
| `impact_flash`, `flare_length` | 1.5, 0.8 m | How bright strokes flare behind the front, and for how far |
| `ignite_time` | 0.15 s | Fallback sweep time when there is no active source |
| `cool_time` | 0.9 s | Hot → cool colour (fast drop, then lingers) |
| `dissolve_start` / `lifetime` | 0.9 / 2.4 s | Burn-away window (accelerates toward the end) |
| `rotation_speed` | 3 °/s | Barely perceptible drift — alive, not mechanical |

Shader notes (`rune_seal.gdshader`): polar coordinates split the band into one cell per glyph;
each glyph is a union of line-segment distance fields. Anti-aliasing uses `fwidth(r)` rather
than `fwidth(d)` — `d` jumps at cell borders and would draw faint seams there.

## SpiritMotes (Phase E — residue)

**Principle: the aftermath sells the event.** After the energy is gone, ~40 tiny motes rise from
the burning seal. They are born ember-warm and cool into the rings' jade as they climb — the fire
releases the spirit, tying the two hues together. Emission tapers off instead of stopping, and
each mote fades on its own, so the effect *ends* rather than *switches off*.

`spirit_motes.tscn` uses the same shared `particle_layer.gd` as the dust, but with continuous
(not one-shot) particles:

| Parameter | Value | Why |
| --- | --- | --- |
| `start_delay` | 0.5 s | Begins as the seal cools — after the impact, not during it |
| `emit_duration`, `emit_taper` | 1.8 s, 1.6 | Rate holds, then tapers to zero (drives `amount_ratio`) |
| emission ring 0.85–1.45 m | | Motes come *from the seal*, not from the drum |
| `initial_velocity` 0.2–0.5, `gravity` +0.15 | | Slow, buoyant rise |
| `turbulence` strength 1, influence 0.05–0.15 | | Wavering, organic paths instead of straight lines |
| `color_ramp` (HDR) | ember → jade → gone | Warm at birth, spirit-coloured as they rise |
| additive, unshaded, `disable_fog` | | Emissive specks of light, like the rings |

**Lesson:** the first version (0.09 m sprites, dim colours) was invisible from the default camera.
A residue has to be faint, but still *legible*. Size and contrast first, then restraint.

## DebrisField (Phase D)

**Principle: matter makes the wave physical.** ~70 low-poly stone shards lie on the ground
*before* the strike. Each one stays still until the pulse front reaches it, then hops outward,
tumbles, bounces and settles. Near shards jump at ~0.1 s, far ones at ~0.6 s — the delay makes
the wave's travel tangible in a way the glowing ring alone can't. Shards beyond the ring's reach
never move, which quietly shows how far the pulse carries.

- Every strike calls `add_push(its PulseRing)` (same `get_front_radius()` contract as the seal).
  Several pushes can travel at once — overlapping strikes each kick the stones. Muted ring →
  a fallback front sweeps at `fallback_front_speed`.
- Push weakens with distance (`falloff_distance`), scales with strength^0.7; small shards fly
  further than big ones.
- A brief, faint jade flick where the pulse touches a shard (`glow_intensity`, `glow_time`).
- Simulated on the CPU (simple ballistics, ~70 instances in one `MultiMeshInstance3D`) — easier
  to direct than a physics engine and cheap at this count.
- The shard mesh is procedural: a jittered 5-sided double pyramid, flat-shaded, scaled
  non-uniformly per instance (`_build_shard_mesh()`).
- Shards stay where they land; repeated strikes push them further out. **R** puts them back.
- `V` (variation) re-scatters the field.

**Lesson:** the first glow (1.5 for 0.5 s) turned the stones into pale paper flakes. The spirit's
touch should be a flick (0.6 for 0.25 s), not a repaint — the shards must still read as stone.

## Drum stand-in (the cause)

`drum_stand_in.gd` builds a low-poly shaman frame drum in code: hide skin (mottled, with a faded
painted circle and axis), wooden rim, cross-handle behind, tripod stand, and a padded beater held
by an invisible hand. It's set in the lab as `Lab.striker`.

**Principle: anticipation.** The effects alone start at impact; the beater adds the phase before:
windup 0.25 s (slow in/out — it gathers and hangs at the top) → swing 0.07 s (accelerating) →
**impact** (emits `impacted`, the lab plays the strike) → rebound 0.45 s. Press **A** to strike
without the windup and compare: the same effect lands with much less weight.

On impact the drum tips back on a damped spring (`recoil`, `recoil_frequency`, `recoil_damping`)
and a faint jade ripple crosses the skin from the contact point (`drum_skin.gdshader`) — the
pulse is born on the drum before it reaches the ground. Strength draws the beater back further,
recoils harder and brightens the ripple.

Not imitated from any real drum: proportions are plausible (≈0.7 m diameter), the painted mark
is deliberately generic. A Blender-authored drum (Stage 6) can replace it later.

## Strength and variation (Phase F)

`DrumStrike.strength` (1 = as authored, keys **−/=**) and `DrumStrike.variation` (key **V**) are
pushed to every layer on `play()`. The composite doesn't know what they mean — each layer's
`set_strength()` / `set_variation()` decides.

**Principle: different properties scale at different rates.** A strike twice as hard is not
twice as big in every way:

| Layer | Brightness | Size / speed | Duration |
| --- | --- | --- | --- |
| Rings | × s | radius × s^0.6, band × s^0.5 | × s^0.3 |
| Rune seal | × s (and flare × s) | — | cooling × s^0.5, life × s^0.3 |
| Dust | — | speed × s^0.7; fewer particles below 1 | — |
| Motes | — | fewer motes below 1; speed unchanged (residue is always calm) | — |
| Debris | — | launch speed × s^0.7 (reach follows the ring's radius) | — |
| Shockwave | bend × s | radius × s^0.6 | × s^0.3 |

So a big strike is mostly *bigger and brighter*, not slower. At 0.3 the ring falls below the glow
threshold entirely — a whisper, not a small explosion. At 2.0 the dust is flung several metres.

`variation` offsets every layer's seed (×101): new wobble, glyphs, dust scatter and mote paths,
while each variation still replays identically. Particle counts above 1 are capped at the
authored `amount` — raise `amount` in the scene if strong strikes need more.

## What to observe

- Press **6** to mute the debris, **5** the motes, **4** the seal, **3** the dust, **2** to mute the echo, **L** to loop, **T** for slow motion. Compare with and without.
- Watch the last half second: without the echo the effect ends abruptly; with it, it settles.

## Try next

- Echo `start_delay` 0.05 vs 0.12 vs 0.3 — find where it stops being "one strike".
- Three rings with decreasing intensity — does it get richer, or just busier?
- Dust: `radial_velocity_max` 8 → 14 (debris-like violence) vs 4 (a sigh). Which suits a *spiritual* strike?
- Dust `start_delay` 0.03–0.05 s: matter reacting a beat after the energy.
- Seal: `rotation_speed` 0 vs 3 vs 30. Where does "alive" turn into "UI spinner"?
- Seal: point `ignition_source` at `EchoRing` instead — a slower, softer ignition.
- Watch the ignition at **T** slow motion with the camera zoomed in; at full speed it lasts ~0.07 s.
- Drum: **A** on/off at **T** slow motion — where exactly does the weight come from?
- Drum: `swing_time` 0.07 vs 0.2 — a strike vs a tap.
- Debris: **L** loop for a while — the field slowly clears around the drum (a story in itself).
- Debris: `gravity` 9.8 vs 20 — floaty vs. heavy, snappy stones.
- Strength 0.25 → 2.0 in steps: which layer stops "scaling" convincingly first?
- Is a weak strike more interesting when it's *different* (e.g. no seal at all below 0.5)
  rather than just smaller? That's the next step beyond uniform scaling.
- Motes: `turbulence_influence_max` 0.15 vs 0.5 — wandering spirit vs. swarm of insects.
- Motes: all jade (no ember start) vs. current — does the colour shift tell the story?
- Dust sprite is perfectly round — a noise-textured sprite would read more organic (Stage 3 shader work).
