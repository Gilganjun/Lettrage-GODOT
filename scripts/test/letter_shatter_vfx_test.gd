extends Node2D

## Preview letter destroy styles — keys 1/2/3 pick style, Space spawns random letter.

const CATALOG := preload("res://resources/letters/alphabet_catalog.tres")
const LetterShatterEffectScript := preload("res://scripts/letters/letter_shatter_effect.gd")

@onready var label: Label = $CanvasLayer/Panel/Margin/VBox/HintLabel
@onready var style_label: Label = $CanvasLayer/Panel/Margin/VBox/StyleLabel

var _letters: PackedStringArray = PackedStringArray(["A", "E", "M", "R", "Z"])
var _letter_index := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				LetterShatterEffectScript.active_style = LetterShatterEffectScript.Style.GRID_SHATTER
				_refresh_labels()
			KEY_2:
				LetterShatterEffectScript.active_style = LetterShatterEffectScript.Style.PIXEL_BURST
				_refresh_labels()
			KEY_3:
				LetterShatterEffectScript.active_style = LetterShatterEffectScript.Style.SOFT_DISSOLVE
				_refresh_labels()
			KEY_SPACE:
				_spawn_demo_shatter()
			KEY_ESCAPE:
				get_tree().quit()


func _spawn_demo_shatter() -> void:
	var ch: String = _letters[_letter_index % _letters.size()]
	_letter_index += 1
	var path := CATALOG.get_texture_path(ch)
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var modulate := CATALOG.get_letter_modulate(ch)
	var scale_factor := _rng.randf_range(0.32, 0.48)
	var spawn_pos := Vector2(480, 300) + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-20, 20))
	LetterShatterEffectScript.spawn(
		self,
		spawn_pos,
		tex,
		modulate,
		Vector2.ONE * scale_factor,
		LetterShatterEffectScript.active_style,
	)


func _refresh_labels() -> void:
	if style_label:
		style_label.text = "Active: %s" % LetterShatterEffectScript.style_name(
			LetterShatterEffectScript.active_style
		)
