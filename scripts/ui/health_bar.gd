extends Control

## Screen-fixed health bar — fixed width, clipped fill.

@export var bar_color := Color(0.35, 0.92, 0.55, 1.0)
@export var bar_max_width := 124.0
@export var show_numeric_debug := false

@onready var box: Panel = $VBox/Box
@onready var fill: ColorRect = $VBox/Box/Fill
@onready var title_label: Label = $VBox/TitleLabel
@onready var value_label: Label = $VBox/ValueLabel

var _health: Node


func setup(label_text: String, health: Node, color: Color = bar_color, title_color: Color = Color(0.15, 0.2, 0.28, 1.0)) -> void:
	if title_label:
		title_label.text = label_text
		title_label.add_theme_color_override("font_color", title_color)
		title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		title_label.add_theme_constant_override("shadow_offset_x", 1)
		title_label.add_theme_constant_override("shadow_offset_y", 1)
	bar_color = color
	if fill:
		fill.color = color
	_health = health
	if _health:
		_health.health_changed.connect(_on_health_changed)
		call_deferred("_refresh_fill", _health.current_health, _health.max_health)


func set_debug_numeric_visible(enabled: bool) -> void:
	show_numeric_debug = enabled
	value_label.visible = enabled
	_refresh_labels(_health.current_health if _health else 0, _health.max_health if _health else 0)


func _on_health_changed(current: int, maximum: int) -> void:
	_refresh_fill(current, maximum)


func _refresh_fill(current: int, maximum: int) -> void:
	if fill == null or box == null:
		return
	var ratio := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	var inner_h := maxf(1.0, box.size.y - 4.0)
	fill.size = Vector2(bar_max_width * ratio, inner_h)
	fill.position = Vector2(2.0, 2.0)
	_refresh_labels(current, maximum)


func _refresh_labels(current: int, maximum: int) -> void:
	if show_numeric_debug:
		value_label.text = "%d / %d" % [current, maximum]
