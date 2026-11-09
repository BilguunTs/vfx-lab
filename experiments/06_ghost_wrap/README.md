# 06 Ghost Wrap

A reusable component that dissolves any set of meshes into smoke, driven by one value:

| `intensity` | Look |
| --- | --- |
| 0 | The model as authored (original materials, no smoke) |
| 0.5 | Part solid, part smoke |
| 1 | No body left, only a floating smoke shape of the figure |

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
| 1 / 2 | Mute dissolve / smoke |
| D | Debug: reveal origin (white cross), dissolve front (yellow circles), current smoke emission points (cyan) |
| T, L, R | Slow motion, loop, reset |

## Using it on anything

`ghost_wrap.gd` is self-contained. To use it on your own mesh:

1. Add a `Node3D` with `ghost_wrap.gd` as a child of the body, at the feet, +Y up.
2. Put the body's `MeshInstance3D`s in `targets`.
3. Optional: add a `Node3D`/`Marker3D` where the transition should start and assign it to
   `reveal_point`. Empty = the bottom centre of the body.
4. Animate `intensity` from anything: a script, an `AnimationPlayer`, a `Tween`.

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
- **Puffs (`ghost_smoke.gdshader`):** procedural, no textures. A puff is *not* a picture of
  smoke: it's a very soft window onto one shared density field (value-noise fbm with a slight
  swirl distortion) that lives in **world space** and scrolls upward. Overlapping puffs reveal
  the same structure, so hundreds of faint puffs merge into one volume. Each quad is stretched
  along the particle's velocity (streaks, not dots). The density threshold rises over life, so
  puffs disperse into wisps. Fake self-shadowing: denser-above = darker, thin edges = lighter.
  Soft contact (depth fade) where they meet the floor or the body.

### How real smoke behaves, and what each rule maps to

| Real smoke | Implementation |
| --- | --- |
| One continuous, connected volume, never separate blobs | World-space shared noise field; many faint puffs (`smoke_opacity` 0.3, 360 puffs) |
| Smooth near the source, turbulent higher up (laminar → turbulent, e.g. cigarette smoke) | `turbulence_influence_over_life`: 10 % at birth → 100 % at half life |
| A plume widens and thins as it rises (it pulls in surrounding air) | Scale curve 25 % → 100 % (≈4× growth); density threshold rises with age |
| Stretches along its flow | Particle Y aligned to velocity; quad `smoke_stretch` × taller |
| Dense parts self-shadow, thin parts glow with scattered light | Shaded from the field's density gradient: `smoke_lit_color` / `smoke_shadow_color` |
| Rises because it's warm (buoyancy) | `smoke_rise` acceleration + upward-scrolling field |

**Principle: replace, don't remove.** Smoke comes exactly from where the body disappears (most
of it at the moving edge), so the eye reads the body as *becoming* smoke rather than being cut away.

## Parameters (on `Body/GhostWrap`)

| Parameter | Default | What it does |
| --- | --- | --- |
| `intensity` | 0 | Master control, 0..1 |
| `reveal_point` | empty | Node where transitions start (empty = bottom centre of the body) |
| `edge_band` | 0.2 | Width of the soft solid↔smoke zone (fraction of the body's extent from the point) |
| `edge_noise`, `edge_noise_scale`, `edge_flow` | 0.1, 5, 0.25 | How ragged, how fine, how fast the edge moves |
| `body_opacity` | 1.0 | Opacity of the solid part during a transition (lower = see-through spirit) |
| `desaturate`, `rim_strength`, `edge_glow`, `glow_color` | 0.5, 0.35, 0.2, pale jade | Colour treatment |
| `smoke_amount`, `smoke_lifetime` | 360, 3 s | Density and trail length (*rebuild*) |
| `smoke_opacity` | 0.3 | Per-puff opacity. Low: smoke is many faint layers |
| `smoke_size`, `smoke_stretch` | 0.9 m, 1.7 | Final puff width (born at ¼), height/width along motion |
| `smoke_lit_color`, `smoke_shadow_color` | pale jade, dark slate | Thin/lit vs. dense/shadowed smoke |
| `smoke_rise`, `smoke_push`, `smoke_turbulence` | 0.45, 0.15, 0.35 | Buoyancy, outward push, curl (ramps up with age) |
| Shader: `field_scale`, `field_rise`, `warp`, `thin_start/end`, `shade_contrast` | in `ghost_smoke.gdshader` | Size of smoke structure, scroll, curliness, dispersal, self-shadow |
| `edge_smoke` | 2 | Extra smoke from the moving edge vs. fully dissolved areas. 0 = even |

*Rebuild* parameters only apply when `rebuild()` runs (on ready). Everything else is live:
edit it in the Remote inspector while the game runs.

## What to observe

- Mute the smoke (**2**): the fade alone looks like a hologram. With smoke it becomes a spirit.
- Mute the fade (**1**): smoke alone reads as "on fire" or "steaming", not ghostly.
- Press Space mid-ramp: the transition reverses smoothly from wherever it is.
- Same reveal point, both directions: from Feet, ghosting eats the legs first; reveal from Feet
  and the legs come back first. Compare with Head (**P**).
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
- At ~360 alpha-blended puffs this is cheap, but overdraw grows with `smoke_size` × `smoke_amount`.

## Try next

- `edge_smoke` 0 vs 2 vs 6: smoke from the whole dissolved area vs. a burning edge.
- `edge_band` 0.05 (sharp, burning-paper front) vs 0.4 (slow misty blend).
- `smoke_rise` −0.1 (sinking, cold) vs 0.45 vs 1.0 (rising, hot). Which is more *ghost*?
- `body_opacity` 0.6: a fully translucent spirit vs. a solid body with a missing lower half.
- `wander` on (in `ghost_wrap_demo.tscn` on the root): the smoke trails behind a moving body.
- Dark smoke (`smoke_lit_color` / `smoke_shadow_color` near black, higher `smoke_opacity`) for a malevolent spirit. Does the dark
  background still read it?
- `field_scale` 1.2 (big lazy billows) vs 4 (fine, busy smoke): which matches the figure's scale?
- `smoke_stretch` 1 vs 3: billowing vs. streaming.
- Tendrils: add a second layer of particle **trails** (`TubeTrailMesh`) for a few long wisps
  curling off the shoulders. Different look (strands rather than volume); try it as a layer.
