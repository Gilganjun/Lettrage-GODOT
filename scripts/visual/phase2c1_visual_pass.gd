class_name Phase2C1VisualPass
extends Node

## Bounded visual hierarchy pass for phase2c1 only. Set enabled = false to skip.

@export var enabled := true

@onready var focus_band: GameplayFocusBand = $GameplayFocusBand
@onready var background_blur: BackgroundBlur = $BackgroundBlur
@onready var platform_pass: PlatformReadability = $PlatformReadability


func setup(
	level_root: Node2D,
	spawner: LetterSpawnDirector,
	word_controller: WordGameController,
	enemy: Enemy,
	combat_hud: Control,
	player_root: Node2D,
	enemy_root: Node2D,
) -> void:
	if not enabled:
		return
	focus_band.apply_to_level(level_root)
	background_blur.configure_level(level_root)
	platform_pass.apply_to_level(level_root)
	_apply_character_readability(player_root, enemy_root)
	if combat_hud and combat_hud.has_method("set_word_slots_enabled"):
		combat_hud.set_word_slots_enabled(true)


func _apply_character_readability(player_root: Node2D, enemy_root: Node2D) -> void:
	for child in player_root.get_children():
		if child is CharacterBody2D:
			var sprite := child.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			CharacterReadability.apply_player(sprite)
	for child in enemy_root.get_children():
		if child is CharacterBody2D:
			var sprite := child.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			CharacterReadability.apply_enemy(sprite)
