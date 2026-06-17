class_name ProfanityReactionPlayer
extends CanvasLayer

## Shows a brief on-screen message when player or enemy submits a profane word.

signal profanity_reaction_shown(word: String, source: String, message: String)

const ProfanityDictionaryServiceScript := preload(
	"res://scripts/word_game/profanity_dictionary_service.gd"
)

@export var display_seconds := 2.5
@export var messages: PackedStringArray = PackedStringArray([
	"You're naughty!",
	"Don't be rude!",
])

var profanity: RefCounted = ProfanityDictionaryServiceScript.new()

var _label: Label
var _panel: PanelContainer
var _hide_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 25
	_rng.randomize()
	if not profanity.load_dictionary():
		push_warning(profanity.error_message)
	_build_ui()


func _process(delta: float) -> void:
	if _hide_timer <= 0.0:
		return
	_hide_timer -= delta
	if _hide_timer <= 0.0:
		_panel.visible = false


func bind_player_words(word_controller: WordGameController) -> void:
	if word_controller == null:
		return
	if not word_controller.valid_word_submitted.is_connected(_on_player_valid_word):
		word_controller.valid_word_submitted.connect(_on_player_valid_word)


func bind_enemy_words(enemy: Enemy) -> void:
	if enemy == null or not enemy.has_method("get_word_controller"):
		return
	var wc: Node = enemy.get_word_controller()
	if wc and wc.word_state:
		if not wc.word_state.word_completed.is_connected(_on_enemy_word_completed):
			wc.word_state.word_completed.connect(_on_enemy_word_completed)


func show_reaction(word: String, source: String) -> void:
	if not profanity.contains_word(word):
		return
	var message := _pick_message()
	_label.text = message
	_panel.visible = true
	_center_panel()
	_hide_timer = display_seconds
	profanity_reaction_shown.emit(word, source, message)


func _on_player_valid_word(word: String, _word_length: int, _score_delta: int) -> void:
	show_reaction(word, "player")


func _on_enemy_word_completed(word: String) -> void:
	show_reaction(word, "enemy")


func _pick_message() -> String:
	if messages.is_empty():
		return "Don't be rude!"
	return messages[_rng.randi_range(0, messages.size() - 1)]


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.05, 0.08, 0.88)
	style.border_color = Color(1.0, 0.45, 0.55, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.78, 1.0))
	_panel.add_child(_label)

	call_deferred("_center_panel")


func _center_panel() -> void:
	if _panel == null:
		return
	var viewport := get_viewport().get_visible_rect()
	_panel.reset_size()
	var panel_size := _panel.size
	_panel.position = viewport.position + (viewport.size - panel_size) * 0.5
