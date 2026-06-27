class_name LightTex
extends RefCounted
## Shared light texture for the native 2D lights. The soft radial falloff that gives a PointLight2D
## the round, feathered pool the noir look expects is authored as light_radial.tres; this loads it
## once and reuses it, so code-driven lights and authored scenes share the one texture.

const RADIAL := preload("res://src/util/light_radial.tres")


static func radial() -> GradientTexture2D:
	return RADIAL
