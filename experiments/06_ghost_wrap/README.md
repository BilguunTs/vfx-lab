# 06 Ghost Wrap

A reusable component that dissolves any set of meshes into smoke, driven by one value:

| `intensity` | Look |
| --- | --- |
| 0 | The model as authored (original materials, no smoke) |
| 0.5 | Part solid, part smoke |
| 1 | No body left, only a floating smoke shape of the figure (or, with `blob_enabled`, a churning smoke orb) |

What the body dissolves *into* is a swappable **element** (`elements/*.tres`): smoke, fire,
water or wind, each moving according to its own nature (see [Elements](#elements)).

Transitions spread from a **reveal point** you place anywhere on or around the body. Leaving 0
(ghosting), the area around the point dissolves first. Leaving 1 (revealing), the area around
the point turns solid first. Put it at the feet and the legs go first and come back first; put
it at the head and the head does.

## Run

```
/Applications/Godot.app/Contents/MacOS/Godot --path . res://experiments/06_ghost_wrap/ghost_wrap_lab.tscn
```

or open `ghost_wrap_lab.tscn` in the editor and press **F6**. It's the standard lab (same keys)
with the drum hidden and the camera closer.

| Key | Action |
| --- | --- |
| Space | Toggle the target value 0 ↔ 1 (1.6 s for a full ramp) |
| Q / E | Step the target value down / up by 0.25 |
| P | Next reveal point: Feet → Head → RightHand (used from the next transition) |
| B | Toggle the blob (the medium gathers into an orb at full ghost) |
| N | Next element: Smoke → Fire → Water → Wind |
| 1 / 2 | Mute dissolve / particles |
| D | Debug: reveal origin (white cross), dissolve front (yellow circles), current smoke emission points (cyan), blob sphere (violet) |
| T, L, R | Slow motion, loop, reset |

## Using it on anything

`ghost_wrap.gd` is self-contained. To use it on your own mesh:

1. Add a `Node3D` with `ghost_wrap.gd` as a child of the body, at the feet, +Y up.
2. Put the body's `MeshInstance3D`s in `targets`.
3. Optional: add a `Node3D`/`Marker3D` where the transition should start and assign it to
   `reveal_point`. Empty = the bottom centre of the body.
4. Optional: assign an element (`elements/fire.tres`...) to `element`. Empty = smoke.
5. Animate `intensity` from anything: a script, an `AnimationPlayer`, a `Tween`.

**Direction rules.** The point and direction are read at the moment `intensity` leaves 0 or 1.
Reversing mid-transition runs the same front back (no pop). Moving the marker mid-transition
takes effect from the next one.

It knows nothing about its owner. `ghost_wrap_demo.gd` is only the driver for the stand-in
figure (ramp, hover, optional wander, reveal-point keys).

## How it works

- **Dissolve (`ghost_body.gdshader`):** while `intensity > 0`, each target surface gets a
  ShaderMaterial that copies its albedo colour/texture and roughness. Each fragment's distance
  from the reveal origin (normalised by the farthest part of the body, plus upward-flowing
  noise) is compared to a *front* radius computed in `ghost_wrap.gd`. Ghosting: everything
  inside the front is smoke, and the front grows from 0 to past the body. Revealing: everything
  inside is solid. The edge is a soft band (`edge_band`) with a faint glow; a Fresnel rim keeps
  the silhouette. At 0 the original materials come back, so a solid body pays nothing.
- **Smoke:** one GPUParticles3D with *directed* emission points (pushed out along the surface
  normal, then rising). On `rebuild()` 2048 area-weighted samples are taken on the targets.
  Whenever the front moves, 512 emission points are re-chosen from them: dissolved areas emit,
  the moving edge emits extra (`edge_smoke`), solid areas emit nothing. So at 1 the whole body
  emits and the smoke takes its shape. Emission rate = `intensity`. Particles are in world
  space, so a moving body leaves a trail.
- **Puffs (`ghost_medium.gdshaderinc`):** procedural, no textures. A puff is *not* a picture of
  smoke: it's a very soft window onto one shared density field (value-noise fbm with a slight
  swirl distortion) that lives in **world space** and scrolls upward. Overlapping puffs reveal
  the same structure, so hundreds of faint puffs merge into one volume. Each quad is stretched
  along the particle's velocity (streaks, not dots). The density threshold rises over life, so
  puffs disperse into wisps. Fake self-shadowing: denser-above = darker, thin edges = lighter.
  Soft contact (depth fade) where they meet the floor or the body.

### How real smoke behaves, and what each rule maps to

| Real smoke | Implementation |
| --- | --- |
| One continuous, connected volume, never separate blobs | World-space shared noise field; many faint puffs (`opacity` 0.3, 360 puffs) |
| Smooth near the source, turbulent higher up (laminar → turbulent, e.g. cigarette smoke) | `turbulence_influence_over_life`: 10 % at birth → 100 % at half life |
| A plume widens and thins as it rises (it pulls in surrounding air) | Scale curve 25 % → 100 % (≈4× growth); density threshold rises with age |
| Stretches along its flow | Particle Y aligned to velocity; quad `stretch` × taller |
| Dense parts self-shadow, thin parts glow with scattered light | Shaded from the field's density gradient: `lit_color` / `shadow_color` |
| Rises because it's warm (buoyancy) | `gravity` (up) + upward-drifting field (`field_flow`) |

- **Blob (optional, `blob_enabled`):** from `blob_start` (0.7) to 1, each emission point slides
  from the body surface to its own point inside a sphere (`blob_center`, default chest height).
  A `GPUParticlesAttractorSphere3D` pulls puffs back toward the centre, rise is swapped for
  `blob_rise`, puffs turn round (no velocity stretch) and drag goes up. Going back from 1, the
  orb spreads over the body again before the body re-forms from the reveal point.

**Principle: replace, don't remove.** Smoke comes exactly from where the body disappears (most
of it at the moving edge), so the eye reads the body as *becoming* smoke rather than being cut away.

## Elements

An element (`ghost_element.gd`, a Resource) holds everything about the *medium*: colour over
life, puff shape, density field, motion, how the body edge looks, and how it behaves as a blob.
The component holds everything about the *body*: dissolve, reveal point, blob placement.
New element = duplicate a `.tres` and edit it in the Inspector. Swapping takes effect
immediately (the particle system is rebuilt for amount, lifetime and blend mode).

| Element | Motion | Look | Body edge | Blob |
| --- | --- | --- | --- | --- |
| Smoke | Rises slowly, laminar → turbulent, widens 4× | Soft, self-shadowed, pale jade | Faint jade glow | Churning orb |
| Fire | Fast upward tongues, short life (0.9 s), strong buoyancy; **sparks** and **embers** (accents) | **Additive**: white-yellow → orange → deep red → gone | Body chars dark ahead of a glowing orange line | Fireball, slight swirl |
| Water | Falls under gravity (−9 m/s²), droplets stretched along the fall, **collide with the floor** | Dark glossy blue, highlights only where thin | Body darkens as if wet | Water sphere held in the air |
| Wind | Blown one way (4 m/s² sideways), long thin streaks | Barely visible dusty strokes | — | Whirlwind (vector-field swirl) |

### Accents (sparks, embers)

An element can carry secondary layers in `accents` (`ghost_accent.gd`, a Resource). They share
the medium's emission points and are drawn by `ghost_spark.gdshader`: a tiny additive streak
with a bright core, stretched along its motion, with per-particle flicker. Fire has two:

| Accent | Behaviour | Why |
| --- | --- | --- |
| `fire_sparks.tres` | 70, thrown out fast (2.6 m/s), arc down under gravity, 0.6 s, white-hot → orange; `rate_follows_motion` 0.8 | Sparks come from *change*: they crackle while the front moves and drop to 20 % when the fire is steady |
| `fire_embers.tres` | 45, slow (0.35 m/s), drift up on the heat, flutter (turbulence), twinkle, 2.6 s | The steady afterlife of a fire: they keep rising while the body burns |

`rate_follows_motion` blends between a steady rate and one driven by how fast the dissolve
front is moving, so accents can react to the *transition* rather than just its state.

Shaders: `ghost_medium.gdshaderinc` is the shared puff logic; `ghost_medium_mix.gdshader`
(alpha blend: smoke, water, wind) and `ghost_medium_add.gdshader` (additive: fire) only set the
blend mode. `ghost_billboard.gdshaderinc` holds the velocity-aligned billboard both use. Fire must be additive: light never darkens what's behind it.

**Principle: the medium's physics *is* its identity.** The same particle system reads as four
different things mainly through acceleration direction, lifetime, stretch and blend mode, much
more than through colour. Try fire with water's gravity: it stops reading as fire immediately.

## Parameters (on `Body/GhostWrap`)

| Parameter | Default | What it does |
| --- | --- | --- |
| `intensity` | 0 | Master control, 0..1 |
| `element` | empty (smoke) | What the body dissolves into (`elements/*.tres`) |
| `reveal_point` | empty | Node where transitions start (empty = bottom centre of the body) |
| `edge_band` | 0.2 | Width of the soft solid↔medium zone (fraction of the body's extent from the point) |
| `edge_noise`, `edge_noise_scale` | 0.1, 5 | How ragged and how fine the edge is |
| `body_opacity`, `desaturate` | 1.0, 0.5 | Solid part during a transition |
| `edge_smoke` | 2 | Extra particles from the moving edge vs. fully dissolved areas. 0 = even |
| `floor_height` | 0 | World height of the floor, for colliding elements |
| `blob_enabled`, `blob_center`, `blob_radius`, `blob_start` | off, chest, 0.45 m, 0.7 | Blob placement and timing |

Element parameters (on the `.tres`): `amount`, `lifetime`, `color_over_life`, `lit_color` /
`shadow_color`, `opacity`, `additive`, `size`, `birth_scale`, `stretch`; density field
(`field_scale`, `field_flow`, `warp`, `thin_start/end`, `softness`, `shade_contrast`); motion
(`gravity`, `push`, `spread`, `damping`, `turbulence`, `collide_with_floor`, `bounce`); body
edge (`glow_color`, `edge_glow`, `rim_strength`, `edge_flow`, `scorch_color`, `scorch_width`);
blob (`blob_gravity`, `blob_pull`, `blob_swirl`, `blob_damping`, `blob_puff_scale`,
`blob_stretch`). Each is documented in `ghost_element.gd`.

Everything is live: edit it in the Remote inspector while the game runs (element `amount`,
`lifetime`, `additive` and `collide_with_floor` apply when the element is swapped).

## What to observe

- Mute the smoke (**2**): the fade alone looks like a hologram. With smoke it becomes a spirit.
- Mute the fade (**1**): smoke alone reads as "on fire" or "steaming", not ghostly.
- Press Space mid-ramp: the transition reverses smoothly from wherever it is.
- Same reveal point, both directions: from Feet, ghosting eats the legs first; reveal from Feet
  and the legs come back first. Compare with Head (**P**).
- **N** through the elements at the same value (Q/E to 0.5): same body, same front, four
  different materials. Which differences come from motion, which from colour?
- **B** on, Space: the figure dissolves into smoke, which then gathers into an orb. Space
  again: the orb unravels over the body and the body re-forms.
- Q/E to 0.5 and hold: the half state is stable, and smoke keeps pouring from the edge.
- **T** slow motion: the edge noise flows *up*, the same direction as the smoke.

## Known limits

- Emission points are sampled once from the meshes' rest shape. On a **skinned, animated**
  character they won't follow the limbs. Fix later (Stage 8) by sampling per bone or
  re-sampling from the skinned mesh.
- Where the robe is half faded, the opaque part (alpha ≈ 1, written to depth) cuts the smoke
  behind it with a hard outline. It reads as a tattered hem; a wider `edge_band` softens it.
- The reveal sphere is measured in straight lines, not along the body: from the hand, the hip
  next to it dissolves before the shoulder. Fine for a stand-in; a surface-distance version
  would need precomputed geodesic distances (later, if it matters).
- Transparent body parts can sort incorrectly against each other where they overlap
  (`depth_prepass_alpha` keeps the opaque upper body correct).
- At ~360 alpha-blended puffs this is cheap, but overdraw grows with element `size` × `amount` (water: 700 small streaks; fire is additive, so overdraw adds brightness too).

## Try next

- `edge_smoke` 0 vs 2 vs 6: smoke from the whole dissolved area vs. a burning edge.
- Blob: `blob_pull` 1 (loose, breathing) vs 8 (tight core); `blob_start` 0.4 vs 0.9 (how much
  of the transition is spent as a body-shaped cloud).
- `edge_band` 0.05 (sharp, burning-paper front) vs 0.4 (slow misty blend).
- Smoke `gravity.y` −0.1 (sinking, cold) vs 0.45 vs 1.0 (rising, hot). Which is more *ghost*?
- `body_opacity` 0.6: a fully translucent spirit vs. a solid body with a missing lower half.
- `wander` on (in `ghost_wrap_demo.tscn` on the root): the smoke trails behind a moving body.
- A new element: duplicate `smoke.tres`. Ideas: ash (grey, falls slowly, drifts), spirit
  (additive jade, rises, swirls), sand (falls, collides, no stretch).
- Fire accents: sparks `rate_follows_motion` 0 vs 0.8 (constant fizz vs. crackle on change);
  embers `gravity.y` 0.7 vs 0.2 (hot updraft vs. dying fire).
- Accents for other elements: water splashes (fast, falling, short), spirit motes for smoke.
- Dark smoke (`lit_color` / `shadow_color` near black, higher `opacity`) for a malevolent spirit. Does the dark
  background still read it?
- `field_scale` 1.2 (big lazy billows) vs 4 (fine, busy smoke): which matches the figure's scale?
- Smoke `stretch` 1 vs 3: billowing vs. streaming.
- Tendrils: add a second layer of particle **trails** (`TubeTrailMesh`) for a few long wisps
  curling off the shoulders. Different look (strands rather than volume); try it as a layer.
