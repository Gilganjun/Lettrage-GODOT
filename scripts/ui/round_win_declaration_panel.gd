class_name RoundWinDeclarationPanel
extends Control

## Victory breakdown — words spelled and ACTION attacks with damage totals.

enum WordSortMode {
	POINTS_HIGH,
	POINTS_LOW,
	ALPHABETICAL,
	COLLECTION,
}

const FONT := preload("res://assets/Panton-BlackCaps.otf")
const DAMAGE_COL_WIDTH := 52.0
const ROW_HEIGHT := 26.0
const ROW_GAP := 8.0

const SORT_LABELS: Array[String] = [
	"Points (high → low)",
	"Points (low → high)",
	"Alphabetical",
	"Collection order",
]

@export var row_stagger := 0.08
@export var row_fade_duration := 0.2

@onready var _panel: PanelContainer = $Panel
@onready var _scroll: ScrollContainer = $Panel/Margin/Scroll
@onready var _content: VBoxContainer = $Panel/Margin/Scroll/Content

var _words: Array = []
var _attacks: Array = []
var _total_damage := 0
var _sort_mode := WordSortMode.POINTS_HIGH


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func prepare_report(report: Dictionary) -> void:
	_words = (report.get("words", []) as Array).duplicate(true)
	_attacks = (report.get("attacks", []) as Array).duplicate(true)
	_total_damage = int(report.get("total_damage", 0))
	_sort_mode = WordSortMode.POINTS_HIGH
	if _words.is_empty() and _attacks.is_empty():
		hide_panel()
		return
	_rebuild_display(false)
	visible = true
	modulate.a = 0.0


func fade_in(duration: float = 0.45) -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)


func get_orbit_anchor_global() -> Vector2:
	return get_global_rect().get_center()


func show_report(report: Dictionary) -> void:
	_words = (report.get("words", []) as Array).duplicate(true)
	_attacks = (report.get("attacks", []) as Array).duplicate(true)
	_total_damage = int(report.get("total_damage", 0))
	_sort_mode = WordSortMode.POINTS_HIGH
	if _words.is_empty() and _attacks.is_empty():
		hide_panel()
		return
	_rebuild_display(true)


func hide_panel() -> void:
	visible = false
	modulate.a = 1.0
	_words.clear()
	_attacks.clear()
	_total_damage = 0
	_clear_content()


func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()


func _rebuild_display(animate: bool) -> void:
	_clear_content()
	_add_header("VICTORY BREAKDOWN")
	if not _words.is_empty():
		_add_word_sort_bar()
		_add_section_title("WORDS CAST")
		for entry in _sorted_words():
			_add_row(str(entry.get("word", "?")), int(entry.get("damage", 0)), Color(0.98, 0.9, 0.42))
	if not _attacks.is_empty():
		_add_section_title("ACTION STRIKES")
		for entry in _attacks:
			_add_row(str(entry.get("label", "Attack")), int(entry.get("damage", 0)), Color(1.0, 0.62, 0.34))
	_add_divider()
	_add_total_row(_total_damage)
	visible = true
	modulate.a = 1.0
	call_deferred("_sync_content_width")
	if animate:
		_animate_rows()
	else:
		_show_rows_immediately()


func _sorted_words() -> Array:
	var sorted: Array = _words.duplicate(true)
	match _sort_mode:
		WordSortMode.POINTS_HIGH:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var dmg_a := int(a.get("damage", 0))
				var dmg_b := int(b.get("damage", 0))
				if dmg_a == dmg_b:
					return int(a.get("order", 0)) < int(b.get("order", 0))
				return dmg_a > dmg_b
			)
		WordSortMode.POINTS_LOW:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var dmg_a := int(a.get("damage", 0))
				var dmg_b := int(b.get("damage", 0))
				if dmg_a == dmg_b:
					return int(a.get("order", 0)) < int(b.get("order", 0))
				return dmg_a < dmg_b
			)
		WordSortMode.ALPHABETICAL:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("word", "")) < str(b.get("word", ""))
			)
		WordSortMode.COLLECTION:
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("order", 0)) < int(b.get("order", 0))
			)
	return sorted


func _add_word_sort_bar() -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34.0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.modulate.a = 1.0
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = "Sort"
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.98))
	row.add_child(label)

	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_override("font", FONT)
	option.add_theme_font_size_override("font_size", 13)
	for sort_label in SORT_LABELS:
		option.add_item(sort_label)
	option.selected = _sort_mode
	option.item_selected.connect(_on_sort_selected)
	row.add_child(option)
	row.modulate.a = 1.0
	row.remove_meta("declare_row")
	_content.add_child(row)


func _on_sort_selected(index: int) -> void:
	_sort_mode = index as WordSortMode
	_rebuild_display(false)


func _sync_content_width() -> void:
	if _scroll == null or _content == null:
		return
	var width := maxf(_scroll.size.x, custom_minimum_size.x)
	if width <= 0.0:
		width = 460.0
	_content.custom_minimum_size.x = width
	_content.size.x = width
	for child in _content.get_children():
		if child is ColorRect:
			(child as Control).custom_minimum_size.x = width
	_content.queue_sort()


func _word_col_width() -> float:
	var max_chars := 4
	for entry in _words:
		max_chars = maxi(max_chars, str(entry.get("word", "")).length())
	for entry in _attacks:
		max_chars = maxi(max_chars, str(entry.get("label", "")).length())
	return clampf(float(max_chars) * 15.0 + 12.0, 72.0, 148.0)


func _prepare_row(node: Control, min_height: float = ROW_HEIGHT) -> void:
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.custom_minimum_size.y = min_height
	node.modulate.a = 0.0
	node.set_meta("declare_row", true)


func _add_header(text: String) -> void:
	var label := Label.new()
	_prepare_row(label, 34.0)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	_content.add_child(label)


func _add_section_title(text: String) -> void:
	var label := Label.new()
	_prepare_row(label, 24.0)
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.98))
	_content.add_child(label)


func _add_row(label_text: String, damage: int, accent: Color) -> void:
	var row := HBoxContainer.new()
	_prepare_row(row)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_GAP)

	var name_label := Label.new()
	name_label.custom_minimum_size.x = _word_col_width()
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.text = label_text
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	row.add_child(name_label)

	var dmg_label := _make_damage_label("-%d" % damage, 18)
	row.add_child(dmg_label)
	_content.add_child(row)


func _add_divider() -> void:
	var line := ColorRect.new()
	_prepare_row(line, 10.0)
	line.color = Color(0.92, 0.76, 0.28, 0.35)
	_content.add_child(line)


func _add_total_row(total: int) -> void:
	var row := HBoxContainer.new()
	_prepare_row(row, 32.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", ROW_GAP)

	var title := Label.new()
	title.custom_minimum_size.x = _word_col_width()
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.text = "ROUND DAMAGE"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	row.add_child(title)

	var total_label := _make_damage_label("-%d" % total, 22)
	row.add_child(total_label)
	_content.add_child(row)


func _make_damage_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = DAMAGE_COL_WIDTH
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02, 0.92))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _animate_rows() -> void:
	if _content == null:
		return
	var delay := 0.0
	for child in _content.get_children():
		if not child.has_meta("declare_row"):
			continue
		child.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(child, "modulate:a", 1.0, row_fade_duration)\
			.set_delay(delay).set_ease(Tween.EASE_OUT)
		delay += row_stagger


func _show_rows_immediately() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.modulate.a = 1.0
