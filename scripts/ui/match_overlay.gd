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
const CONTINUE_ACTIVATION_DELAY_SEC := 3.0
const CONTINUE_BAR_BOTTOM_MARGIN := 28.0
const CONTINUE_BAR_MAX_WIDTH := 340.0
const VICTORY_STACK_GAP := 14.0
const VICTORY_TOP_CLEARANCE := 72.0
const DECLARATION_DEFAULT_HEIGHT := 320.0

var _continue_activation_seq := 0


func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)
	if _panel:
		_default_panel_style = _panel.get_theme_stylebox("panel")
	if _continue_button and not _continue_button.pressed.is_connected(_on_continue_button_pressed):
		_continue_button.pressed.connect(_on_continue_button_pressed)
	hide_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_layout_victory_ui_stack")


func _process(delta: float) -> void:
	if _continue_input_lockout > 0.0:
		_continue_input_lockout = maxf(_continue_input_lockout - delta, 0.0)


func hide_all() -> void:
	_cancel_continue_activation_schedule()
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
	player_report: Dictionary = {},
	enemy_report: Dictionary = {},
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
	_panel.visible = not manual_continue
	_subtitle.visible = not manual_continue
	_score.visible = not manual_continue
	_prompt.visible = false
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_title.visible = false
	var has_scorecard := RoundWinDeclarationPanel.reports_have_entries(player_report, enemy_report)
	if player_won and _you_win_voice:
		_you_win_voice.play_you_win()
	if has_scorecard:
		_begin_round_end_sequence(player_won, player_report, enemy_report, round_number, match_won)
	else:
		_show_round_end_splash(player_won, round_number, match_won)
		if _round_win_declaration:
			_round_win_declaration.hide_panel()
	call_deferred("_layout_victory_ui_stack")


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
	_hide_continue_bar()
	_set_continue_button_active(false)
	if manual_continue:
		_continue_input_lockout = CONTINUE_ACTIVATION_DELAY_SEC
	else:
		_continue_input_lockout = 0.0
	if match_won and manual_continue:
		_schedule_continue_activation(
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
		_schedule_continue_activation(
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
		_continue_button.disabled = false
		_continue_button.text = button_text
	_focus_continue_button()
	call_deferred("_layout_victory_ui_stack")


func _layout_victory_ui_stack() -> void:
	if not visible:
		return
	_layout_continue_bar()
	_layout_round_win_declaration()


func _layout_continue_bar() -> void:
	if _continue_bar == null or not _continue_bar.visible:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	_continue_bar.reset_size()
	var min_size := _continue_bar.get_combined_minimum_size()
	var width := clampf(
		minf(CONTINUE_BAR_MAX_WIDTH, maxf(min_size.x, 280.0)),
		240.0,
		viewport_rect.size.x - 32.0,
	)
	var height := maxf(min_size.y, 88.0)
	_continue_bar.offset_left = -width * 0.5
	_continue_bar.offset_right = width * 0.5
	_continue_bar.offset_bottom = -CONTINUE_BAR_BOTTOM_MARGIN
	_continue_bar.offset_top = -(CONTINUE_BAR_BOTTOM_MARGIN + height)


func _layout_round_win_declaration() -> void:
	if _round_win_declaration == null or not _round_win_declaration.visible:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var reserved_bottom := CONTINUE_BAR_BOTTOM_MARGIN
	var reserve_continue_space := (
		_manual_continue_active
		and _awaiting_continue
		and _continue_bar != null
	)
	if _continue_bar and (_continue_bar.visible or reserve_continue_space):
		var bar_height := 104.0
		if _continue_bar.visible:
			bar_height = maxf(_continue_bar.offset_bottom - _continue_bar.offset_top, 88.0)
		reserved_bottom += bar_height + VICTORY_STACK_GAP
	var decl_bottom := -reserved_bottom
	var max_decl_height := viewport_rect.size.y - reserved_bottom - VICTORY_TOP_CLEARANCE
	max_decl_height = maxf(max_decl_height, 120.0)
	var decl_width := minf(380.0, viewport_rect.size.x - 32.0)
	var decl_height := minf(DECLARATION_DEFAULT_HEIGHT, max_decl_height)
	_round_win_declaration.offset_left = -decl_width * 0.5
	_round_win_declaration.offset_right = decl_width * 0.5
	_round_win_declaration.offset_bottom = decl_bottom
	_round_win_declaration.offset_top = decl_bottom - decl_height
	_round_win_declaration.custom_minimum_size = Vector2(decl_width, decl_height)


func _set_continue_button_active(active: bool) -> void:
	if _continue_button == null:
		return
	_continue_button.disabled = not active


func _schedule_continue_activation(
	subtitle_text: String,
	score_text: String,
	button_text: String = "Continue  —  Enter / J",
) -> void:
	_continue_activation_seq += 1
	var seq := _continue_activation_seq
	_hide_continue_bar()
	_set_continue_button_active(false)
	_arm_continue_activation_timer(seq, subtitle_text, score_text, button_text)


func _arm_continue_activation_timer(
	seq: int,
	subtitle_text: String,
	score_text: String,
	button_text: String,
) -> void:
	await get_tree().create_timer(CONTINUE_ACTIVATION_DELAY_SEC).timeout
	if seq != _continue_activation_seq or not is_inside_tree():
		return
	_continue_input_lockout = 0.0
	_show_continue_bar(subtitle_text, score_text, button_text)


func _cancel_continue_activation_schedule() -> void:
	_continue_activation_seq += 1


func _focus_continue_button() -> void:
	if _continue_button and _continue_button.visible:
		_continue_button.grab_focus()


func _hide_continue_bar() -> void:
	if _continue_bar:
		_continue_bar.visible = false
	if _continue_button:
		_continue_button.visible = false
		_continue_button.disabled = true


func _on_continue_button_pressed() -> void:
	if _continue_input_lockout > 0.0:
		return
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
	player_report: Dictionary = {},
	enemy_report: Dictionary = {},
	manual_continue: bool = false,
) -> void:
	_hide_round_win_splash()
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_panel.visible = not manual_continue
	_title.visible = false
	_subtitle.visible = not manual_continue
	_score.visible = not manual_continue
	_prompt.visible = not manual_continue
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_awaiting_continue = true
	_manual_continue_active = manual_continue
	_hide_continue_bar()
	var has_scorecard := RoundWinDeclarationPanel.reports_have_entries(player_report, enemy_report)
	if has_scorecard:
		_begin_round_end_sequence(false, player_report, enemy_report, 0, true)
	elif _you_win_splash:
		_show_round_end_splash(false, 0, true)
	if not manual_continue:
		_subtitle.text = line
		_score.text = "Final: %d - %d" % [player_rounds, enemy_rounds]
		_prompt.text = "Press Enter to try again"
		_continue_input_lockout = 0.0
	else:
		_continue_input_lockout = CONTINUE_ACTIVATION_DELAY_SEC
		_schedule_continue_activation(
			"YOU LOSE THE FIGHT",
			"Final: %d - %d" % [player_rounds, enemy_rounds],
			"Try Again  —  Enter / J",
		)
	call_deferred("_layout_victory_ui_stack")


func _show_round_end_splash(player_won_round: bool, round_number: int, fight_subtitle: bool) -> void:
	if _you_win_splash == null:
		return
	var kind := (
		YouWinSplashFx.ResultKind.WIN
		if player_won_round
		else YouWinSplashFx.ResultKind.LOSE
	)
	_you_win_splash.play_splash_centered(kind, round_number, fight_subtitle)


func dismiss_round_result_ui() -> void:
	_cancel_continue_activation_schedule()
	_victory_sequence_id += 1
	_hide_round_win_splash()
	_hide_continue_bar()
	if _round_win_declaration:
		_round_win_declaration.hide_panel()
	_backdrop.visible = false


func _begin_round_end_sequence(
	player_won_round: bool,
	player_report: Dictionary,
	enemy_report: Dictionary,
	round_number: int,
	fight_subtitle: bool,
) -> void:
	_victory_sequence_id += 1
	var seq := _victory_sequence_id
	if _round_win_declaration:
		_round_win_declaration.prepare_dual_reports(
			player_report,
			enemy_report,
			player_won_round,
		)
	_show_round_end_splash(player_won_round, round_number, fight_subtitle)
	_run_round_end_sequence(seq)


func _run_round_end_sequence(seq: int) -> void:
	await get_tree().create_timer(VICTORY_SPLASH_HOLD_SEC).timeout
	if seq != _victory_sequence_id or not is_inside_tree():
		return
	if _round_win_declaration:
		_round_win_declaration.fade_in(VICTORY_TABLE_FADE_SEC)
	call_deferred("_layout_victory_ui_stack")
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
