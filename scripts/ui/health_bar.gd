extends Control

## Screen-fixed health bar — GDevelop width scale 0–130px.

@export var bar_color := Color(0.35, 0.92, 0.55, 1.0)
@export var bar_max_width := 130.0
@export var show_numeric_debug := false

@onready var box: Panel = $Box
@onready var fill: ColorRect = $Box/Fill
@onready var title_label: Label = $VBox/TitleLabel
@onready var value_label: Label = $VBox/ValueLabel

var _health: Node


func setup(label_text: String, health: Node, color: Color = bar_color) -> void:
	title_label.text = label_text
	bar_color = color
	fill.color = color
	_health = health
	if _health:
		_health.health_changed.connect(_on_health_changed)
		_on_health_changed(_health.current_health, _health.max_health)


func set_debug_numeric_visible(enabled: bool) -> void:
	show_numeric_debug = enabled
	value_label.visible = enabled
	_refresh_labels(_health.current_health if _health else 0, _health.max_health if _health else 0)


func _on_health_changed(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	fill.size.x = bar_max_width * ratio
	_refresh_labels(current, maximum)


func _refresh_labels(current: int, maximum: int) -> void:
	if show_numeric_debug:
		value_label.text = "%d / %d" % [current, maximum]
