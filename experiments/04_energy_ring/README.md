# 04 — Energy Ring

**What it demonstrates:** Phase A of the shaman drum strike — a single pulse ring spreading across
the ground from the point of impact.

**Visual principle:** an impact reads through *timing* more than detail. The ring launches fast
and decelerates (ease-out), thins as its energy spreads, and dims quickly before lingering. The
leading edge is crisp and the trailing side soft, so it reads as a pressure wave rather than a
drawn circle. A slight wobble keeps it from looking machine-perfect.

## How it works

- `energy_ring.gd` owns time. Each frame it maps normalized time `t` (0→1) to radius, band width
  and fade, then pushes them as shader uniforms.
- `energy_ring.gdshader` draws a ring on a flat quad from distance-to-centre. It never reads
  `TIME`; noise is advanced by the script, so every replay with the same seed is identical and
  slow motion slows the whole effect.
- Additive, unshaded. Brightness above 1.0 crosses the environment's glow threshold, so
  `intensity` doubles as the glow control.

## Parameters (Inspector)

| Group | Parameter | Effect |
| --- | --- | --- |
| Shape | `start_radius`, `max_radius` | Where the ring starts and stops (m) |
| Shape | `thickness`, `thickness_end_scale` | Band width at start, and how much it thins by the end |
| Shape | `edge_noise` | Radial wobble (m) |
| Timing | `lifetime` | Total duration (s) |
| Timing | `expansion_ease` | < 1 explosive then slow; 1 linear; > 1 slow start |
| Timing | `fade_ease` | < 1 drops fast then lingers; > 1 holds then drops |
| Look | `color`, `intensity` | Tint and brightness/glow |
| Look | `softness`, `wake`, `wake_length` | Edge hardness and the faint trail behind the front |
| Look | `brightness_variation` | Uneven energy along the ring |
| Variation | `noise_seed`, `noise_scale`, `noise_speed` | Shape of the wobble; same seed = same replay |

## What to observe

- Use **T** (slow motion) + **D** (debug). The yellow lines show the current band; grey circles
  show start and max radius. Watch how most of the travel happens in the first ~20 % of lifetime.
- Compare `expansion_ease` 0.3 vs 1.0: linear expansion feels mechanical, not like an impact.
- Push `wake` to 0.5+: the ring turns into a disc and loses its shape. Shape problem, not color.

## Try next

- Phase B: a short particle burst timed to the first frames of the ring.
- A second, fainter ring delayed ~0.1 s (echo) — layering instead of more brightness.
- Replace `ease()` with an exported `Curve` resource to hand-author the timing.
