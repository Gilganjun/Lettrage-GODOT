class_name IntroViewport
extends RefCounted

## Shared viewport constants for standalone GDevelop intro scenes.

const SIZE := Vector2(960, 540)
const CENTER := Vector2(480, 270)


static func gd_opacity_to_alpha(value_0_255: float) -> float:
	return clampf(value_0_255 / 255.0, 0.0, 1.0)


static func gd_zoom_to_godot(zoom_factor: float) -> Vector2:
	# GDevelop layer zoom: larger value = more magnification (same sense as Godot Camera2D.zoom).
	return Vector2.ONE * maxf(zoom_factor, 0.05)
