# Experiment Log

## 2026-10-10 — Stage 1: lab + energy ring

- Built the sandbox (`lab/`) and experiment 04, a shader-drawn ground ring with script-driven timing.
- **Lesson — float hashes cause seams.** The first noise used a `fract`-based float hash. It
  produced hard radial seams and stepped edges because rounding differences made the same lattice
  point hash differently from neighbouring cells. Switched to an integer (`uint`) hash.
- **Lesson — wake too strong reads as a disc.** At `wake` 0.25 / `wake_length` 0.8 the inside
  filled in and the silhouette was lost. 0.12 / 0.4 keeps it a ring with a soft trailing side.
- Validated by rendering frames with `--write-movie` and a headless smoke test of the controls.

## 2026-10-10 — Echo ring (experiment 05)

- Added `start_delay` to the ring and a `DrumStrike` scene that triggers child layers together.
  The lab now loads it; keys 1–9 mute layers for A/B.
- Echo: same ring, 0.12 s later, dimmer/cooler/thinner, longer-lived. Result: the strike gains
  weight and decays in two steps instead of switching off. The echo becomes the lingering
  element — a natural starting point for Phase E (residue).

## 2026-10-10 — Dust burst (Phase B)

- Added `DustBurst`: one-shot GPUParticles3D, 64 lit alpha-blended puffs, radial velocity with a
  decaying curve. Built-in GradientTexture2D as the sprite — no texture files.
- **Lesson — first pass was too timid.** The radial curve died at 30 % life and damping was high,
  so dust stayed within ~0.8 m of the drum while the ring travelled 4.5 m: read as a puff, not a
  kick-out. Stronger/longer radial push + low damping → ~2.5 m, still lagging the ring.
- **Lesson — debug markers must be small.** Full-size opaque debug quads merged into one blob;
  0.08 m markers show the spread clearly.
- Verified: GPU particles respect `Engine.time_scale` in 4.6, so slow motion stays in sync.

## 2026-10-10 — Rune seal (Phase C)

- Added `RuneSeal`: procedural glyph circle (spine + slanted strokes per cell), ignites in random
  order, cools ember → dark red, burns away via noise dissolve with a hot edge.
- Extracted `shared/shaders/noise.gdshaderinc` and `shared/debug_draw.gd` now that two
  experiments use them.
- **Lesson — anti-alias with a continuous quantity.** `fwidth(d)` on a per-cell distance field
  smeared faint lines along cell borders (d is discontinuous there). `fwidth(r)` fixes it.
- **Lesson — size for the camera.** At 0.7–1.2 m the glyphs were mush from the default view;
  0.85–1.45 m with 14 glyphs reads. Always judge from the gameplay distance, not a close-up.

## 2026-10-10 — Seal ignited by the ring

- `EnergyRing.get_front_radius()` + `RuneSeal.ignition_source`: the pulse front now writes the
  glyphs as it passes, with a short flare behind the front. Falls back to a timed sweep if the
  ring is muted.
- Since all glyphs sit at the same radius, ring-driven ignition is *radial* (each glyph written
  inner → outer), not around the circle. Lasts ~0.07 s at full speed: felt more than seen.

## 2026-10-10 — Residue: spirit motes (Phase E)

- Added `SpiritMotes`: continuous GPUParticles3D trickle from the seal band, ember → jade colour
  ramp, buoyant rise with turbulence, emission tapered via `amount_ratio`. Ends ~5.3 s after the strike.
- Extracted `shared/effect_components/particle_layer.gd` (delay, seed, one-shot vs tapered
  emission, debug markers); DustBurst now uses it too.
- **Lesson — faint must still be legible.** 0.09 m dim motes vanished at the default camera
  distance; 0.2 m with a bright core + soft halo reads while staying restrained.
- Lab loop interval raised to 5.5 s so replays don't cut off the aftermath.

## 2026-10-10 — Strength and variation (Phase F)

- `DrumStrike.strength` / `variation`, forwarded to each layer's `set_strength()` /
  `set_variation()`. Lab keys −/= and V strike immediately for quick A/B.
- Per-property exponents: brightness × s, size × s^0.6, duration × s^0.3. Verified visually:
  0.3 reads as a quiet tap (no glow), 2.0 as a violent blow (wide ring, dust flung far).
- Particle layers duplicate their process material at startup and scale speeds from the
  authored values; counts only scale down (amount_ratio ≤ 1).

## 2026-10-10 — Debris kicked by the pulse (Phase D)

- Added `DebrisField`: ~70 procedural low-poly shards resting on the ground, launched one by one
  when the ring's front reaches them; CPU ballistics + bounce, one MultiMeshInstance3D,
  per-instance glow via INSTANCE_CUSTOM. Replays identical (`restore_on_play`).
- Difference from the dust: dust is *emitted* by the strike; debris *already exists* and the
  pulse acts on it. Arrival delay by distance makes the wave's travel tangible.
- **Lesson — keep matter looking like matter.** Strong long glow made stones read as paper; a
  faint 0.25 s flick keeps the "spirit touched it" idea without losing the material.

## 2026-10-10 — Drum stand-in (anticipation + cause)

- Procedural frame drum + tripod + beater replaces the hex pillar. Beater: windup → swing →
  impact (`impacted` signal → lab plays the effect) → rebound. Drum recoils on a damped spring;
  a jade ripple crosses the skin. Key A toggles anticipation for A/B.
- **Lesson — `.tscn` Transform3D text is row-major.** Hand-written yaw put the drum's face away
  from the camera (we saw the cross-handle side). Verified with `var_to_str()` and fixed. The
  Stage 1 sun transform was written the same way (transposed); it still lights the scene well,
  so it was left as is — but generate transforms with Godot rather than by hand.
- **Lesson — impact flash on a lit surface blows out easily.** Skin emission ×3 went pure white;
  ×1.5 keeps it a glow on the hide.

## 2026-10-10 — Overlapping strikes

- Feedback: replaying reset every layer mid-effect, which felt wrong. Now each strike spawns its
  own *voice* (`drum_voice.tscn`) that plays out and frees itself; strikes stack. DebrisField
  stays single and persistent, receiving each strike's pulse via `add_push()`; shards no longer
  snap back on every hit (R restores them).
- The drum queues presses made mid-swing (up to 3): beats land every ~0.35 s with the beater
  going straight from the skin into the next windup — rhythm instead of a stuck windup.
- Lab loop interval 5.5 s → 2.5 s, since overlapping no longer cuts anything off.
- Result: rapid hits read as concentric ripples and a seal that burns brighter with each beat.

## 2026-11-09 — Ghost wrap (experiment 06)

- New reusable component `ghost_wrap.gd`: any meshes + one `intensity` value. Body-space height
  fade with flowing noise edge (materials swapped only while active), plus GPU smoke from
  area-weighted surface samples biased toward the fading region (directed emission points).
- Lab gained `effect_scene` so an experiment can run in it through an inherited scene.
- **Lesson — smoke that reads as foam is a shape problem.** First pass: 0.45 m puffs at 0.4
  opacity, born at 35 % size, read as countable bubbles. Bigger (0.8 m), fainter (0.22), born
  at 50 % size, with noise dominating the round falloff → reads as one smoke volume.
- **Lesson — replace, don't remove.** The fade alone looks like a hologram cut. Emitting the
  smoke densest where the body disappears makes the legs read as *becoming* smoke.
- Edge glow 0.3 tinted the whole lower robe jade (neon read); 0.2 keeps it a hint.
- Validated with `--write-movie` frames (smoke on/off) and a headless script exercising debug,
  mute, reset and replay.

## 2026-11-09 — Ghost smoke, second pass: from bubbles to a volume

- Feedback: the smoke still read as floating bubbles. Researched how real smoke behaves and how
  real-time smoke usually fails (uniform round puffs read as fake).
- **Lesson — a puff is a window, not a picture.** Each puff had its own noise inside a circle,
  so the eye counted circles. Sampling one shared density field in *world space* makes
  overlapping puffs show the same structure → one connected volume. This was the decisive fix.
- Added the plume behaviours: laminar → turbulent (turbulence over life 10 % → 100 %), widening
  (scale 25 % → 100 %), dispersal (density threshold rises with age), stretch along velocity,
  fake self-shadowing from the field's vertical density gradient.
- Shaders now use game time (`scaled_time`), not `TIME`, so **T** slow motion slows them too.
- First pass at opacity 0.15 was too faint to read as a volume; 0.3 holds it.

## 2026-11-09 — Ghost wrap: full range + reveal point

- Value now spans model (0) → half (0.5) → only smoke in the body's shape (1). The bottom-up
  fade became a sphere around a placeable `reveal_point`; transitions start there in both
  directions (ghosting: point dissolves first; revealing: point solidifies first).
- Smoke emission points are re-chosen from a 2048-sample pool whenever the front moves:
  dissolved areas emit, the edge emits extra, solid areas none. At 1 the smoke takes the body's shape.
- **Lesson — latch on the transition edge, not on the rest state.** First version re-read the
  reveal point every frame while resting at 0/1. The demo sets the point and moves the value in
  the same frame, and the parent processes before the child, so the component never saw the new
  point. Now it is read at the moment intensity *leaves* 0 or 1.
- Verified with a scripted render (screenshots of feet ghosting, full ghost, head revealing,
  back to model, hand ghosting) and a mid-transition reversal (front continuous, mode kept).

## 2026-11-09 — Ghost wrap: optional smoke blob

- `blob_enabled`: from intensity 0.7 to 1 the emission points slide onto a sphere and a
  `GPUParticlesAttractorSphere3D` holds the smoke there, so full ghost is a churning orb.
- **Lesson — velocity stretch + attractor = petals.** Puffs swing through the attractor fast;
  stretched along velocity, every swing became a radial streak (a dandelion). In the blob,
  puffs go round and drag rises (late, blob²) so they settle and churn.
- **Lesson — light from the field, never from the sprite.** Thin-edge brightening used the
  puff's own round window, giving each puff a bright rim. Invisible while puffs overlapped
  heavily, obvious as rings once they were round and sparse. Now it uses the shared field only.
- Small, round, non-overlapping puffs read as dots again (same lesson as the first pass):
  blob puffs are 1.3× larger so they merge.

## 2026-11-09 — Ghost wrap: swappable elements (smoke, fire, water, wind)

- The medium became a `GhostElement` resource (`elements/*.tres`): colour over life, puff
  shape, density field, motion, body-edge treatment, blob behaviour. The component keeps the
  body side (dissolve, reveal point, blob placement). Shader split into a shared include plus
  mix / additive wrappers (blend mode is compile-time in Godot).
- Fire: additive, 0.9 s life, strong buoyancy, HDR colour ramp; body chars ahead of a glowing
  edge (`scorch_color`). Water: gravity −9, long thin streaks, floor collision
  (GPUParticlesCollisionBox3D), wet darkening. Wind: sideways acceleration, faint dusty streaks;
  blob is a whirlwind from a procedural GPUParticlesAttractorVectorField3D.
- **Lesson — physics is identity.** Colour alone didn't separate them; acceleration direction,
  lifetime, stretch and blend mode did.
- **First-pass misses:** fire too blown out (HDR 3 → 1.8, opacity 0.4); water read as pale ice
  flakes (darker, thinner, faster); wind read as hay (one direction, fainter, less turbulence).
  Water blob read as beads (puffs 5× larger to merge); wind blob drew radial petals: the inward
  pull beat the swirl and the outward birth push drew radial streaks (push → 0 in the blob,
  pull 2 → 0.6, `blob_stretch` per element).
- Test-harness note: scripted screenshots hang when the test window is covered (macOS stops
  drawing it). Run with `--always-on-top`.

## 2026-11-09 — Fire accents: sparks and embers

- New `GhostAccent` resource: small additive particle layers an element carries in
  `accents`, sharing the medium's emission points. `ghost_spark.gdshader`: bright core + halo,
  velocity-stretched, irregular per-particle twinkle. Billboard code extracted to
  `ghost_billboard.gdshaderinc`.
- Sparks: fast, gravity-arced, 0.6 s, rate tied to how fast the dissolve front moves
  (`rate_follows_motion`): they crackle during transitions and calm to 20 % at rest.
  Embers: slow, buoyant, fluttering, twinkling, 2.6 s, steady.
- **Lesson — tie accents to change, not state.** Sparks at a constant rate read as a sparkler;
  driven by the front's speed they read as the act of burning. Reveal (body re-forming out of
  fire) showers sparks around the robe and is the most striking moment.

## 2026-11-09 — Shockwave (air distortion)

- `experiments/07_shockwave`: expanding sphere whose shader re-samples the screen texture,
  pushing pixels away from the centre in a fresnel-shaped band with an inward rebound lobe.
  Standalone `trigger(strength)`; added as the `Shockwave` layer of the drum voice.
- Default bend raised 0.025 → 0.04: against the dark lab it was invisible except in diffs.
- Shader compile stalled the first strike; the component (and the drum strike's voice
  prototype) now render once invisibly at load. First strike's worst frame: 11 ms.
- **Lesson — distortion needs detail behind it.** On an empty background it does nothing;
  it reads through the floor stones and the drum. A richer floor would sell it more than a
  stronger amplitude.
- Couldn't be seen in the lab at all (flat floor, black sky). Added **G** test grid to the lab
  (gridded floor + camera-facing backdrop, `lab/test_pattern.gdshader`) and a debug tint on
  the wave (orange push / blue rebound). With the grid the bend is obvious.

## 2026-11-09 — Live tuning panel

- **Tab** in the lab: sliders generated from a layer's exported ranged int/float properties
  (`lab/tuning_panel.gd`), layer dropdown defaulting to Shockwave. Releasing a slider strikes.
  Print outputs changed values in .tscn syntax; Reset restores the scene's values.
- DrumStrike records tweaks (`set_tuning`) and applies them to each new voice, since every
  strike is a fresh instance and direct edits would be lost.
- Generic: any effect offering get_tunable_layers / get_tunable / set_tuning gets the panel.

## 2026-11-09 — Lab ground

- Flat grey floor replaced by `lab/ground.gdshader`: packed earth with damp/dry patches,
  irregular pebbles (lighter *and* darker than the earth), Voronoi dry cracks only in dry
  patches, a fine bump, and a trampled ring around the drum. `lab/stone_scatter.gd`: flat-shaded
  low-poly stones (4 shapes via MultiMesh, clustered) and boulders beyond the debris field.
- Kept average brightness equal to the old floor (measured on frames), so tuned effects still read.
- **Lessons.** `source_color` uniforms are sRGB: the first pass came out 35 % darker than
  intended. Round pebbles at one tone read as snow / polka dots; varied tone and lumpy outlines
  fixed it. For distortion, *lines* (cracks) sell the bend far better than isolated dots.

## 2026-11-09 — Spirit wisp

- `experiments/08_spirit_wisp`: steering-driven wisp (wander noise, curiosity, personal space,
  hesitation), fear + slower wariness, startle timed to the pulse ring's front via the drum's
  `add_push`. Breathing additive glow, ground light, ribbon trail.
- Motion validated from position logs before rendering. First version: the return was a
  1.8 m/s charge straight back (spring force grows with distance). Fixed by steering to a
  speed-capped velocity plus a wariness state: now it hovers at a distance and creeps back
  over ~8 s.
- Trail: a smooth ribbon read as a comet / laser. Breakup keyed to *life* didn't help (a fast
  flight is all young), keyed to *distance* it did. Then dashes looked like tracer rounds:
  tying the width to the same mask makes each fragment swell and taper.
- **Lesson — validate behaviour numerically.** A position/fear log over 20 s caught the wrong
  return immediately; stills would have shown nothing.

## 2026-11-09 — Three spirits

- Three wisps (Bold, Timid, Loner) under a `Spirits` group layer (`wisp_group.gd`), one mute
  key; the tuning panel lists `Spirits/<name>` to tune each.
- Log showed all wisps first drifting to the focus: simplex noise is 0 at the origin, so each
  started with the same wander target. Offset the noise per seed. Timid needed a
  `preferred_distance` to read as shy before any strike (curiosity alone wasn't enough).
  The loner, 6 m away, barely reacted; a longer `startle_reach` gives it a late twitch.
- Observation: after a strike the spirit motes and the wisps are both pale dots.

## 2026-11-09 — Ghost figures among the spirits

- `ghost_spirit.gd` extends the wisp: same motion and fear, but the look is a small hooded
  figure with Ghost Wrap. Fear → ghost value (rest 0.65, startle → 1 fast, re-form slowly).
  Timid and Loner are now ghost figures; Bold stays a wisp of light.
- **Bug found in Ghost Wrap:** it assumed every body starts solid (`_rest = 0`). A body that
  starts as smoke and is lowered was treated as "leaving 0" and ghosted from the reveal point
  (head dissolved, legs solid: upside down). `_ready` now takes the rest state from the initial
  intensity. Caught by the debug text ("ghosting from RevealHead") on a close-up render.
- Planned "dissolve from the drum side" dropped: re-latching the origin mid-value makes the
  edge jump. Reveal point at the head instead: dissolve feet first, re-form head first.
