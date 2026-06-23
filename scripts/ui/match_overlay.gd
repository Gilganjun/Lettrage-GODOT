class_name MatchOverlay
extends CanvasLayer

signal continue_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $Center/ContentVBox/Panel
@onready var _title: Label = $Center/ContentVBox/Panel/VBox/TitleLabel
@onready var _subtitle: Label = $Center/ContentVBox/Panel/VBox/SubtitleLabel
@onready var _score: Label = $Center/ContentVBox/Panel/VBox/ScoreLabel
@onready var _prompt: Label = $Center/ContentVBox/Panel/VBox/PromptLabel
@onready var _continue_bar: VBoxContainer = $RoundContinueBar
@onready var _continue_subtitle: Label = $RoundContinueBar/ContinueSubtitle
@onready var _continue_score: Label = $RoundContinueBar/ContinueScore
@onready var _continue_button: Button = $RoundContinueBar/ContinueButton
@onready var _you_win_splash: YouWinSplashFx = $YouWinSplashLayer/YouWinSplashFx
@onready var _fight_announcement: FightAnnouncementFx = $Center/ContentVBox/FightAnnouncementFx
@onready var _you_win_voice: YouWinVoicePlayer = $YouWinVoicePlayer
@onready var _fight_start_voice: FightStartVoicePlayer = $FightStartVoicePlayer
@onready var _round_start_splash: RoundStartSplashFx = $RoundSplashCenter/RoundStartSplashFx
@onready var _round_start_voice: RoundStartVoicePlayer = $RoundStartVoicePlayer
@onready var _round_win_declaration: RoundWinDeclarationPanel = $RoundWinDeclaration

var _awaiting_continue := false
var _manual_continue_active := false
var _continue_input_lockout := 0.0
var _default_panel_style: StyleBox
var _victory_sequence_id := 0

const VICTORY_SPLASH_HOLD_SEC := 2.0
const VICTORY_TABLE_FADE_SEC := 0.5


func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)
	if _panel:
		_default_panel_style = _panel.get_theme_stylebox("panel")
	if _continue_button and not _continue_button.pressed.is_connected(_on_continue_button_pressed):
		_continue_button.pressed.connect(_on_continue_button_pressed)
	hide_all()


func _process(delta: float) -> void:
	if _continue_input_lockout > 0.0:
		_continue_input_lockout = maxf(_continue_input_lockout - delta, 0.0)


func hide_all() -> void:
	dismiss_round_result_ui()
	visible = false
	_awaiting_continue = false
	_manual_continue_active = false
	_continue_input_lockout = 0.0
	_panel.visible = false
	_title.visible = false
	_subtitle.visible = false
	_score.visible = false
	_prompt.visible = false
	if _fight_announcement:
		_fight_announcement.stop_announcement()
	if _fight_start_voice:
		_fight_start_voice.cancel_scheduled_play()
	if _round_start_splash:
		_round_start_splash.stop_splash()
	if _round_start_voice and _round_start_voice.has_method("stop"):
		_round_start_voice.stop()


func show_round_start(round_number: int, hold_duration: float = 2.0) -> void:
	dismiss_round_result_ui()
	if _fight_announcement:
		_fight_announcement.stop_announcement()
	if _fight_start_voice:
		_fight_start_voice.cancel_scheduled_play()
	visible = true
	_backdrop.visible = false
	_panel.visible = false
	_title.visible = false
	_subtitle.visible = false
	_score.visible = false
	_prompt.visible = false
	_awaiting_continue = false
	if _round_start_splash:
		_round_start_splash.hold_duration = hold_duration
		_round_start_splash.play_for_round(round_number)
	if _round_start_voice:
		_round_start_voice.play_for_round(round_number)


func show_countdown(number: int) -> void:
	dismiss_round_result_ui()
	if _fight_announcement:
		_fight_announcement.stop_announcement()
	if _fight_start_voice:
		_fight_start_voice.cancel_scheduled_play()
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.35)
	_panel.visible = true
	_title.visible = true
	_title.text = str(number)
	_title.modulate = Color(1.0, 0.95, 0.55, 1.0)
	_subtitle.visible = false
	_score.visible = false
	_prompt.visible = false
	_awaiting_continue = false


func show_fight() -> void:
	_hide_round_win_splash()
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.25)
	_panel.visible = false
	_title.visible = false
	_subtitle.visible = false
	_score.visible = false
	_prompt.visible = false
	_awaiting_continue = false
	if _fight_announcement:
		_fight_announcement.play_announcement()
	if _fight_start_voice:
		_fight_start_voice.schedule_play()


func show_round_result(
	player_won: bool,
	player_rounds: int,
	enemy_rounds: int,
	round_number: int,
	countdown_seconds: int,
	match_won: bool = false,
	victory_report: Dictionary = {},
	manual_continue: bool = false,
) -> void:
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	_configure_round_continue_ui(
		manual_continue,
		player_won,
		player_rounds,
		enemy_rounds,
		round_number,
		countdown_seconds,
		match_won,
	)
	if player_won:
		_panel.visible = not manual_continue
		_subtitle.visible = not manual_continue
		_score.visible = not manual_continue
		_prompt.visible = false
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_title.visible = false
		if _you_win_voice:
			_you_win_voice.play_you_win()
		if _round_win_declaration and not victory_report.is_empty():
			_begin_victory_breakdown_sequence(victory_report)
		else:
			_show_round_win_splash()
			if _round_win_declaration:
				_round_win_declaration.hide_panel()
		if manual_continue:
			call_deferred("_focus_continue_button")
		elif not manual_continue and not match_won:
			_subtitle.text = "Round %d complete" % round_number
			_score.text = "Match: %d - %d" % [player_rounds, enemy_rounds]
	else:
		_panel.visible = not manual_continue
		_subtitle.visible = not manual_continue
		_score.visible = not manual_continue
		_hide_round_win_splash()
		if _round_win_declaration:
			_round_win_declaration.hide_panel()
		if _default_panel_style:
			_panel.add_theme_stylebox_override("panel", _default_panel_style)
		_title.visible = true
		_title.text = "YOU LOSE"
		_title.modulate = Color(1.0, 0.42, 0.38, 1.0)
		if not manual_continue:
			_subtitle.text = "Round %d complete" % round_number
			_score.text = "Match: %d - %d" % [player_rounds, enemy_rounds]
		else:
			call_deferred("_focus_continue_button")


func _configure_round_continue_ui(
	manual_continue: bool,
	player_won: bool,
	player_rounds: int,
	enemy_rounds: int,
	round_number: int,
	countdown_seconds: int,
	match_won: bool,
) -> void:
	_awaiting_continue = true
	_manual_continue_active = manual_continue
	_continue_input_lockout = 0.5 if _manual_continue_active else 0.0
	_hide_continue_bar()
	if match_won and manual_continue:
		_show_continue_bar(
			"YOU WIN THE FIGHT!",
			"Final: %d - %d" % [player_rounds, enemy_rounds],
			"Fight Again  —  Enter / J",
		)
		return
	if match_won:
		_panel.visible = true
		_subtitle.visible = true
		_score.visible = true
		_prompt.visible = true
		_prompt.text = "Press Enter to fight again"
		return
	if manual_continue:
		_prompt.visible = false
		_show_continue_bar(
			"Round %d complete" % round_number,
			"Match: %d - %d" % [player_rounds, enemy_rounds],
		)
		return
	_panel.visible = true
	_subtitle.visible = true
	_score.visible = true
	_prompt.visible = true
	if player_won:
		_subtitle.text = "Round %d complete — next round in %d" % [round_number, countdown_seconds]
		_score.text = "Match: %d - %d" % [player_rounds, enemy_rounds]
		_prompt.text = "Press J to fight now"
	else:
		_subtitle.text = "Round %d complete — next round in %d" % [round_number, countdown_seconds]
		_score.text = "Match: %d - %d" % [player_rounds, enemy_rounds]
		_prompt.text = "Press J to fight now"


func _show_continue_bar(
	subtitle_text: String,
	score_text: String,
	button_text: String = "Continue  —  Enter / J",
) -> void:
	if _continue_bar == null:
		return
	if _continue_subtitle:
		_continue_subtitle.text = subtitle_text
	if _continue_score:
		_continue_score.text = score_text
	_continue_bar.visible = true
	if _continue_button:
		_continue_button.visible = true
		_continue_button.text = button_text
		_focus_continue_button()


func _focus_continue_button() -> void:
	if _continue_button and _continue_button.visible:
		_continue_button.grab_focus()


func _hide_continue_bar() -> void:
	if _continue_bar:
		_continue_bar.visible = false
	if _continue_button:
		_continue_button.visible = false


func _on_continue_button_pressed() -> void:
	_request_continue()


func _request_continue() -> void:
	if not _awaiting_continue:
		return
	dismiss_round_result_ui()
	_awaiting_continue = false
	_manual_continue_active = false
	_continue_input_lockout = 0.0
	continue_requested.emit()


func update_inter_round_countdown(seconds: int) -> void:
	if _manual_continue_active:
		return
	if seconds > 0:
		var round_text := _subtitle.text.get_slice(" — ", 0)
		_subtitle.text = "%s — next round in %d" % [round_text, seconds]


func show_match_victory(line: String, player_rounds: int, enemy_rounds: int) -> void:
	_hide_round_win_splash()
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_panel.visible = true
	_title.visible = true
	_title.text = line
	_title.modulate = Color(1.0, 0.88, 0.35, 1.0)
	_subtitle.visible = true
	_subtitle.text = "YOU WIN THE FIGHT!"
	_score.visible = true
	_score.text = "Final: %d - %d" % [player_rounds, enemy_rounds]
	_prompt.visible = true
	_prompt.text = "Press Enter to fight again"
	_hide_continue_bar()
	_awaiting_continue = true


func show_match_defeat(
	line: String,
	player_rounds: int,
	enemy_rounds: int,
	manual_continue: bool = false,
) -> void:
	_hide_round_win_splash()
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_panel.visible = not manual_continue
	_title.visible = not manual_continue
	_title.text = line
	_title.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_subtitle.visible = not manual_continue
	_subtitle.text = "YOU LOSE THE FIGHT"
	_score.visible = not manual_continue
	_score.text = "Final: %d - %d" % [player_rounds, enemy_rounds]
	_prompt.visible = not manual_continue
	_prompt.text = "Press Enter to try again"
	_awaiting_continue = true
	_manual_continue_active = manual_continue
	_continue_input_lockout = 0.5 if manual_continue else 0.0
	if manual_continue:
		_show_continue_bar(
			"YOU LOSE THE FIGHT",
			"Final: %d - %d" % [player_rounds, enemy_rounds],
			"Try Again  —  Enter / J",
		)
	else:
		_hide_continue_bar()


func _show_round_win_splash() -> void:
	if _you_win_splash:
		_you_win_splash.play_splash_centered()


func dismiss_round_result_ui() -> void:
	_victory_sequence_id += 1
	_hide_round_win_splash()
	_hide_continue_bar()
	if _round_win_declaration:
		_round_win_declaration.hide_panel()
	_backdrop.visible = false


func _begin_victory_breakdown_sequence(report: Dictionary) -> void:
	_victory_sequence_id += 1
	var seq := _victory_sequence_id
	if _round_win_declaration:
		_round_win_declaration.prepare_report(report)
	_show_round_win_splash()
	_run_victory_breakdown_sequence(seq)


func _run_victory_breakdown_sequence(seq: int) -> void:
	await get_tree().create_timer(VICTORY_SPLASH_HOLD_SEC).timeout
	if seq != _victory_sequence_id or not is_inside_tree():
		return
	if _round_win_declaration:
		_round_win_declaration.fade_in(VICTORY_TABLE_FADE_SEC)
	await get_tree().create_timer(VICTORY_TABLE_FADE_SEC).timeout
	if seq != _victory_sequence_id or not is_inside_tree():
		return
	if _you_win_splash and _round_win_declaration:
		_you_win_splash.begin_orbit(_round_win_declaration.get_orbit_anchor_global())


func _hide_round_win_splash() -> void:
	if _you_win_splash:
		_you_win_splash.stop_splash()
	if _fight_announcement:
		_fight_announcement.stop_announcement()
	if _fight_start_voice:
		_fight_start_voice.cancel_scheduled_play()


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_continue:
		return
	if event.is_echo():
		return
	if _continue_input_lockout > 0.0:
		return
	if event.is_action_pressed("round_continue") \
			or (_manual_continue_active and event.is_action_pressed("submit_word")) \
			or (_manual_continue_active and event.is_action_pressed("player_action")):
		_request_continue()
		get_viewport().set_input_as_handled()
