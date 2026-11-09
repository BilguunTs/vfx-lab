class_name GhostAccent
extends Resource
## A small secondary particle layer that accompanies an element: sparks and embers for fire,
## later perhaps motes for a spirit or splashes for water. Emitted from the same points as the
## element's medium (the dissolved parts of the body), drawn as tiny additive glowing streaks.

@export var display_name := "Sparks"
## Particles alive at full rate.
@export_range(1, 2000, 1) var amount := 60
@export_range(0.05, 8.0, 0.05, "suffix:s") var lifetime := 0.6
## Random shortening of individual lifetimes (0 = all equal).
@export_range(0.0, 1.0, 0.01) var lifetime_randomness := 0.5
## Colour and brightness over life. Use values above 1: these are light sources.
@export var color_over_life: Gradient
@export_range(0.005, 0.5, 0.001, "suffix:m") var size := 0.035
## Length / width along the motion. Sparks are streaks; embers are nearly round.
@export_range(1.0, 20.0, 0.1) var stretch := 6.0
## Initial speed away from the surface.
@export_range(0.0, 10.0, 0.01, "suffix:m/s") var push := 2.5
@export_range(0.0, 180.0, 1.0, "suffix:°") var spread := 50.0
## Constant acceleration: gravity for sparks, buoyancy for embers.
@export var gravity := Vector3(0.0, -4.0, 0.0)
@export_range(0.0, 10.0, 0.05) var damping := 1.0
## Fluttering (share of the motion taken over by noise, like the medium's turbulence).
@export_range(0.0, 3.0, 0.01) var turbulence := 0.0
## Per-particle brightness flicker (0 = steady, 1 = strong twinkle).
@export_range(0.0, 1.0, 0.01) var flicker := 0.3
## 0 = steady rate while the body is dissolved; 1 = only while the edge is moving (crackle).
@export_range(0.0, 1.0, 0.01) var rate_follows_motion := 0.0
