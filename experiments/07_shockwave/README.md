# 07 — Shockwave (air distortion)

**What it demonstrates:** a ripple of compressed air that bends the background outward as it
passes. Nothing is drawn: the effect re-samples the already-rendered screen with an offset.

**Visual principle:** physical presence without light. The strike *moves the air*; you read the
force from what's behind the wave bending, not from a bright ring. Fast and short (0.45 s):
a sharp push at the front, then a small inward rebound so the air wobbles once and settles.

## How it works

- `shockwave.gd` grows a sphere mesh from 0 to `max_radius`, decelerating like a blast front
  (`1 - (1-t)^expansion_sharpness`), while the bend decays (`(1-t)^decay`).
- `shockwave.gdshader` samples `hint_screen_texture`. How far we look through the shell
  (fresnel, `1 - dot(NORMAL, VIEW)`) gives a profile: a push band at the rim, an inward rebound
  lobe inside it, fading to zero exactly at the silhouette (no hard outline). Pixels are offset
  along the screen direction away from the sphere's centre.
- It's a sphere, so it reads from any camera angle.
- Self-contained: `trigger(strength)` or `play()`. Used as the `Shockwave` layer of the drum
  strike (`05_drum_strike/drum_voice.tscn`, placed at drum height).

## Parameters

| Parameter | Default | Effect |
| --- | --- | --- |
| `max_radius` | 3.0 m | Final size (× strength^0.6) |
| `lifetime` | 0.45 s | Duration (× strength^0.3) |
| `expansion_sharpness` | 3.0 | High = bursts out then crawls |
| `amplitude` | 0.04 | Peak bend as a fraction of the screen (× strength) |
| `decay` | 1.5 | How fast the bend fades |
| `front_width` | 0.35 | Width of the push band |
| `rebound` | 0.35 | Inward wobble behind the front |
| `edge_light` | 0.1 | Faint brightening on the front |
| `chroma` | 0 | Colour split; 0 for air, a little reads as "magical" |

## Run

Drum strike lab (`lab/lab.tscn`, the main scene): Space strikes, **6** mutes the shockwave
layer for A/B. Debris moved from key 6 to **7**.

- **G** — test grid. The lab's floor is one flat colour and the sky is near-black, so there is
  nothing for the wave to bend. The grid gives it straight lines; turn it on to judge the effect.
- **D** — debug: tints the bend (orange = pushed outward, blue = pulled back) and draws the
  sphere. **T** slow motion helps too: the whole wave is under half a second.

## What to observe

- The floor stones and the drum bulge outward as the front passes, then spring back.
- With **G** off the wave is nearly invisible: distortion needs detail behind it. That's correct
  for air; in a real scene (textured ground, props) it reads. Push `amplitude` only if it must
  read on empty backgrounds.

## Known limits

- Godot's screen texture only holds opaque geometry: dust, rings and smoke are not bent, and
  inside the wave band they are hidden behind the (bent) opaque scene for a moment. At 0.45 s
  this is barely visible.
- One screen copy per frame while active — cheap, but don't stack dozens.
- First use compiles the shader; the component draws itself invisibly on load to avoid a hitch.

## Try next

- `amplitude` 0.02 vs 0.08 — felt vs. cartoonish.
- `rebound` 0 vs 0.6 — a push vs. a wobble.
- `chroma` 0 vs 0.3 — air vs. spirit energy.
- A flattened sphere (scale Y 0.3) hugging the ground under the ring.
