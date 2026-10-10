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
