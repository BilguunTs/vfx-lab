class_name GhostElement
extends Resource
## What a GhostWrap body dissolves into: the look and the physics of the medium.
## Presets live in elements/ (smoke, fire, water, wind). Duplicate one to make a new element.
## Defaults are the smoke element.

@export var display_name := "Smoke"

@export_group("Puffs")
## Particles alive at full intensity.
@export_range(8, 4000, 1) var amount := 360
@export_range(0.1, 8.0, 0.05, "suffix:s") var lifetime := 3.0
## Colour (multiplies the shading) and opacity over each puff's life. Empty = plain white,
## quick fade in, long fade out. Use values above 1 with `additive` for glowing media.
@export var color_over_life: Gradient
## Colour of thin / lit parts of the medium.
@export var lit_color := Color(0.62, 0.7, 0.7)
## Colour of dense parts in their own shadow.
@export var shadow_color := Color(0.16, 0.2, 0.22)
## Opacity of a single puff.
@export_range(0.0, 1.0, 0.01) var opacity := 0.3
## Glowing media (fire): puffs add light instead of covering what's behind.
@export var additive := false
## Final puff width.
@export_range(0.02, 3.0, 0.01, "suffix:m") var size := 0.9
## Puff size at birth, relative to `size`. Smoke grows a lot; droplets don't.
@export_range(0.05, 2.0, 0.01) var birth_scale := 0.25
## Height / width, stretched along the motion. 1 = round.
@export_range(1.0, 8.0, 0.05) var stretch := 1.7

## Secondary layers (sparks, embers...) emitted with the medium.
@export var accents: Array[GhostAccent] = []

@export_group("Density field")
## Frequency of the shared density field per metre: low = big billows, high = fine detail.
@export_range(0.2, 20.0, 0.1) var field_scale := 2.2
## How the field drifts through the world (m/s): smoke up, water down, wind sideways.
@export var field_flow := Vector3(0.0, 0.35, 0.0)
## Curling distortion of the field.
@export_range(0.0, 3.0, 0.01) var warp := 0.6
## Density threshold at birth and death: higher = thinner, more broken up.
@export_range(0.0, 1.5, 0.01) var thin_start := 0.2
@export_range(0.0, 1.5, 0.01) var thin_end := 0.55
## Edge softness: low = crisp droplets, high = soft haze.
@export_range(0.01, 1.0, 0.01) var softness := 0.35
## Fake self-shadowing.
@export_range(0.0, 10.0, 0.1) var shade_contrast := 3.0

@export_group("Motion")
## Constant acceleration: buoyancy (up), gravity (down) or wind (sideways).
@export var gravity := Vector3(0.0, 0.45, 0.0)
## Initial speed away from the surface.
@export_range(0.0, 5.0, 0.01, "suffix:m/s") var push := 0.15
## Random spread around the surface normal.
@export_range(0.0, 180.0, 1.0, "suffix:°") var spread := 25.0
## Drag.
@export_range(0.0, 10.0, 0.05) var damping := 0.45
## Curling. Weak at birth, full strength from half life.
@export_range(0.0, 2.0, 0.01) var turbulence := 0.35
@export_range(0.1, 10.0, 0.1) var turbulence_scale := 2.0
## Puffs hit the floor (GhostWrap.floor_height) instead of passing through.
@export var collide_with_floor := false
@export_range(0.0, 1.0, 0.01) var bounce := 0.1
@export_range(0.0, 1.0, 0.01) var friction := 0.6

@export_group("Body edge")
@export var glow_color := Color(0.55, 0.8, 0.75)
## Glow along the dissolving edge.
@export_range(0.0, 5.0, 0.01) var edge_glow := 0.2
## Fresnel rim on the body during a transition.
@export_range(0.0, 2.0, 0.01) var rim_strength := 0.35
## How the edge pattern drifts (m/s).
@export var edge_flow := Vector3(0.0, 0.25, 0.0)
## Colour the body takes just ahead of the edge (alpha = strength), e.g. char for fire,
## wet darkening for water.
@export var scorch_color := Color(0.0, 0.0, 0.0, 0.0)
## Width of that zone, as a fraction of the body's extent.
@export_range(0.0, 0.5, 0.01) var scorch_width := 0.0

@export_group("Blob")
## Constant acceleration once the blob has formed (replaces `gravity`).
@export var blob_gravity := Vector3(0.0, 0.05, 0.0)
## Pull toward the blob centre.
@export_range(0.0, 20.0, 0.1) var blob_pull := 3.0
## Swirl around the blob's vertical axis (a whirlwind). 0 = none.
@export_range(0.0, 20.0, 0.1) var blob_swirl := 0.0
## Drag once formed: higher = puffs settle and churn instead of overshooting.
@export_range(0.0, 10.0, 0.1) var blob_damping := 2.5
## Stretch inside the blob. 1 = round: puffs swinging through the centre would otherwise turn
## into radial petals. Keep it high for media whose look *is* the streak (wind, with swirl).
@export_range(1.0, 8.0, 0.05) var blob_stretch := 1.0
## Puff size inside the blob, relative to `size`.
@export_range(0.1, 3.0, 0.01) var blob_puff_scale := 1.3
