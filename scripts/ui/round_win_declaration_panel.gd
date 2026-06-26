class_name RoundWinDeclarationPanel
extends Control

## Tabbed round scorecard — words and ACTION attacks for player and enemy.

enum FighterTab {
	PLAYER,
	ENEMY,
}

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
@export var tab_blink_speed := 2.0

const PLAYER_ACCENT := Color(0.32, 0.92, 0.48, 1.0)
const PLAYER_ACCENT_DIM := Color(0.18, 0.55, 0.32, 1.0)
const ENEMY_ACCENT := Color(0.95, 0.32, 0.36, 1.0)
const ENEMY_ACCENT_DIM := Color(0.58, 0.16, 0.2, 1.0)

@onready var _panel: PanelContainer = $Panel
@onready var _tab_bar: HBoxContainer = $Panel/Margin/RootVBox/TabBar
@onready var _scroll: ScrollContainer = $Panel/Margin/RootVBox/Scroll
@onready var _content: VBoxContainer = $Panel/Margin/RootVBox/Scroll/Content

var _player_report: Dictionary = {}
var _enemy_report: Dictionary = {}
var _active_tab := FighterTab.PLAYER
var _words: Array = []
var _attacks: Array = []
var _total_damage := 0
var _sort_mode := WordSortMode.POINTS_HIGH
var _player_tab_btn: Button
var _enemy_tab_btn: Button
var _tab_blink_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_tab_bar()
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not visible:
		return
	_tab_blink_phase += delta * tab_blink_speed
	var pulse := 0.78 + 0.22 * (0.5 + 0.5 * sin(_tab_blink_phase))
	_update_tab_styles(pulse)


func _build_tab_bar() -> void:
	if _tab_bar == null:
		return
	_player_tab_btn = _make_tab_button("PLAYER", FighterTab.PLAYER)
	_enemy_tab_btn = _make_tab_button("ENEMY", FighterTab.ENEMY)
	_tab_bar.add_child(_player_tab_btn)
	_tab_bar.add_child(_enemy_tab_btn)
	_player_tab_btn.pressed.connect(_on_player_tab_pressed)
	_enemy_tab_btn.pressed.connect(_on_enemy_tab_pressed)
	_update_tab_styles()


func prepare_dual_reports(
	player_report: Dictionary,
	enemy_report: Dictionary,
	default_player_tab: bool,
) -> void:
	_player_report = player_report.duplicate(true)
	_enemy_report = enemy_report.duplicate(true)
	_active_tab = FighterTab.PLAYER if default_player_tab else FighterTab.ENEMY
	_sort_mode = WordSortMode.POINTS_HIGH
	if not _has_any_entries():
		hide_panel()
		return
	_update_tab_styles()
	_load_active_report_data()
	_rebuild_display(false)
	visible = true
	modulate.a = 0.0
	set_process(true)


func prepare_report(report: Dictionary) -> void:
	prepare_dual_reports(report, {}, true)


func fade_in(duration: float = 0.45) -> void:
	if not visible:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT)


func get_orbit_anchor_global() -> Vector2:
	return get_global_rect().get_center()


func show_report(report: Dictionary) -> void:
	prepare_dual_reports(report, {}, true)
	_rebuild_display(true)


func hide_panel() -> void:
	visible = false
	modulate.a = 1.0
	set_process(false)
	_player_report.clear()
	_enemy_report.clear()
	_words.clear()
	_attacks.clear()
	_total_damage = 0
	_clear_content()


static func reports_have_entries(player_report: Dictionary, enemy_report: Dictionary) -> bool:
	return _report_has_entries(player_report) or _report_has_entries(enemy_report)


static func _report_has_entries(report: Dictionary) -> bool:
	if report.is_empty():
		return false
	return not report.get("words", []).is_empty() or not report.get("attacks", []).is_empty()


func _has_any_entries() -> bool:
	return reports_have_entries(_player_report, _enemy_report)


func _on_player_tab_pressed() -> void:
	_set_active_tab(FighterTab.PLAYER)


func _on_enemy_tab_pressed() -> void:
	_set_active_tab(FighterTab.ENEMY)


func _set_active_tab(tab: FighterTab) -> void:
	if _active_tab == tab:
		return
	_active_tab = tab
	_sort_mode = WordSortMode.POINTS_HIGH
	_update_tab_styles()
	_load_active_report_data()
	_rebuild_display(false)


func _load_active_report_data() -> void:
	var report := _active_report()
	_words = (report.get("words", []) as Array).duplicate(true)
	_attacks = (report.get("attacks", []) as Array).duplicate(true)
	_total_damage = int(report.get("total_damage", 0))


func _active_report() -> Dictionary:
	return _player_report if _active_tab == FighterTab.PLAYER else _enemy_report


func _make_tab_button(label_text: String, fighter: FighterTab) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = false
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 40.0
	button.text = label_text
	button.modulate = Color.WHITE
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.set_meta("fighter_tab", fighter)
	return button


func _update_tab_styles(pulse: float = 1.0) -> void:
	_style_tab_button(_player_tab_btn, FighterTab.PLAYER, _active_tab == FighterTab.PLAYER, pulse)
	_style_tab_button(_enemy_tab_btn, FighterTab.ENEMY, _active_tab == FighterTab.ENEMY, pulse)


func _style_tab_button(button: Button, fighter: FighterTab, selected: bool, pulse: float) -> void:
	if button == null:
		return
	button.modulate = Color.WHITE
	var accent := PLAYER_ACCENT if fighter == FighterTab.PLAYER else ENEMY_ACCENT
	var accent_dim := PLAYER_ACCENT_DIM if fighter == FighterTab.PLAYER else ENEMY_ACCENT_DIM
	var bg := Color(0.05, 0.08, 0.12, 0.92)
	var border := accent_dim
	var font := accent.lerp(Color(0.92, 0.96, 1.0), 0.35)
	if selected:
		bg = accent.darkened(0.18).lerp(accent, 0.35 + 0.25 * pulse)
		border = accent.lightened(0.12 + 0.1 * pulse)
		font = Color(0.98, 1.0, 0.98, 1.0)
	var normal := _make_tab_stylebox(bg, border, 2 if selected else 1)
	var hover := _make_tab_stylebox(bg.lightened(0.08), border.lightened(0.06), 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_pressed_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_disabled_color", font)
	button.add_theme_color_override("font_focus_color", font)
	button.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.9))
	button.add_theme_constant_override("outline_size", 3)


func _make_tab_stylebox(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(6)
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.content_margin_left = 10
	box.content_margin_right = 10
	return box


func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()


func _rebuild_display(animate: bool) -> void:
	_clear_content()
	var header := "PLAYER ROUND LOG" if _active_tab == FighterTab.PLAYER else "ENEMY ROUND LOG"
	var header_color := PLAYER_ACCENT if _active_tab == FighterTab.PLAYER else ENEMY_ACCENT
	_add_header(header, header_color)
	if _words.is_empty() and _attacks.is_empty():
		_add_empty_message()
	else:
		if not _words.is_empty():
			_add_word_sort_bar()
			_add_section_title("WORDS CAST")
			for entry in _sorted_words():
				var accent := (
					Color(0.98, 0.9, 0.42)
					if _active_tab == FighterTab.PLAYER
					else Color(0.82, 0.62, 1.0)
				)
				_add_row(str(entry.get("word", "?")), int(entry.get("damage", 0)), accent)
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


func _add_empty_message() -> void:
	var label := Label.new()
	_prepare_row(label, 48.0)
	label.text = "No words or attacks logged this round."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
	_content.add_child(label)


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


func _add_header(text: String, accent: Color = Color(1.0, 0.92, 0.45)) -> void:
	var label := Label.new()
	_prepare_row(label, 30.0)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", accent.lightened(0.18))
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
