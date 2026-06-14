class_name CharacterVisualProfile
extends Resource

## Visual/data definition for a character role — independent from controller or AI logic.
## Gameplay systems assign a profile; swapping artwork does not require code changes.

@export var character_id: String = ""
@export var role_label: String = ""
@export var sprite_frames: SpriteFrames

## Explicit animation sequence order from GAME25.json (never alphabetized at runtime).
@export var animation_order: Array[String] = []

@export var modulate: Color = Color.WHITE
@export var display_scale: float = 0.45

# GDevelop effect metadata (Main2_heallthbartest baseline)
@export var glow_enabled: bool = false
@export var glow_color: Color = Color.WHITE
@export var glow_distance: float = 0.0
@export var glow_inner_strength: float = 0.0
@export var glow_outer_strength: float = 0.0

@export var night_effect_enabled: bool = false
@export var night_intensity: float = 0.0
@export var night_opacity: float = 0.0

@export_multiline var source_effect_notes: String = ""


func get_effect_summary() -> String:
	var parts: PackedStringArray = []
	if modulate != Color.WHITE:
		parts.append(
			"modulate=(%.2f, %.2f, %.2f, %.2f)" % [modulate.r, modulate.g, modulate.b, modulate.a]
		)
	if glow_enabled:
		parts.append(
			"Glow RGB(%d,%d,%d) dist=%.0f inner=%.0f outer=%.0f"
			% [
				int(glow_color.r * 255),
				int(glow_color.g * 255),
				int(glow_color.b * 255),
				glow_distance,
				glow_inner_strength,
				glow_outer_strength,
			]
		)
	if night_effect_enabled:
		parts.append("DarkNight intensity=%.2f opacity=%.2f" % [night_intensity, night_opacity])
	if parts.is_empty():
		return "none (default white)"
	return ", ".join(parts)


func has_animation(anim_name: String) -> bool:
	return animation_order.has(anim_name)


func get_animation_count() -> int:
	return animation_order.size()
