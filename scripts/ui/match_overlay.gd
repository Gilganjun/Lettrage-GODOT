class_name MatchOverlay
extends CanvasLayer

signal continue_requested

@onready var _backdrop: ColorRect = $Backdrop
@onready var _panel: PanelContainer = $Center/ContentVBox/Panel
@onready var _title: Label = $Center/ContentVBox/Panel/VBox/TitleLabel
@onready var _subtitle: Label = $Center/ContentVBox/Panel/VBox/SubtitleLabel
@onready var _score: Label = $Center/ContentVBox/Panel/VBox/ScoreLabel
@onready var _prompt: Label = $Center/ContentVBox/Panel/VBox/PromptLabel
@onready var _you_win_splash: YouWinSplashFx = $Center/ContentVBox/YouWinSplashFx
@onready var _fight_announcement: FightAnnouncementFx = $Center/ContentVBox/FightAnnouncementFx
@onready var _you_win_voice: YouWinVoicePlayer = $YouWinVoicePlayer
@onready var _fight_start_voice: FightStartVoicePlayer = $FightStartVoicePlayer

var _awaiting_continue := false
var _default_panel_style: StyleBox


func _ready() -> void:
	if _panel:
		_default_panel_style = _panel.get_theme_stylebox("panel")
	hide_all()


func hide_all() -> void:
	visible = false
	_awaiting_continue = false
	_backdrop.visible = false
	_panel.visible = false
	_title.visible = false
	_subtitle.visible = false
	_score.visible = false
	_prompt.visible = false
	if _you_win_splash:
		_you_win_splash.stop_splash()
	if _fight_announcement:
		_fight_announcement.stop_announcement()
	if _fight_start_voice:
		_fight_start_voice.cancel_scheduled_play()


func show_countdown(number: int) -> void:
	_hide_round_win_splash()
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
) -> void:
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.62)
	_panel.visible = true
	_subtitle.visible = true
	_score.visible = true
	_prompt.visible = true
	_awaiting_continue = true
	if player_won:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_title.visible = false
		_show_round_win_splash()
		if _you_win_voice:
			_you_win_voice.play_you_win()
		if match_won:
			_subtitle.text = "YOU WIN THE FIGHT!"
			_score.text = "Final: %d - %d" % [player_rounds, enemy_rounds]
			_prompt.text = "Press Enter to fight again"
		else:
			_subtitle.text = "Round %d complete — next round in %d" % [round_number, countdown_seconds]
			_score.text = "Match: %d - %d" % [player_rounds, enemy_rounds]
			_prompt.text = "Press J to fight now"
	else:
		_hide_round_win_splash()
		if _default_panel_style:
			_panel.add_theme_stylebox_override("panel", _default_panel_style)
		_title.visible = true
		_title.text = "YOU LOSE"
		_title.modulate = Color(1.0, 0.42, 0.38, 1.0)
		_subtitle.text = "Round %d complete — next round in %d" % [round_number, countdown_seconds]
		_score.text = "Match: %d - %d" % [player_rounds, enemy_rounds]
		_prompt.text = "Press J to fight now"


func update_inter_round_countdown(seconds: int) -> void:
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
	_awaiting_continue = true


func show_match_defeat(line: String, player_rounds: int, enemy_rounds: int) -> void:
	_hide_round_win_splash()
	visible = true
	_backdrop.visible = true
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_panel.visible = true
	_title.visible = true
	_title.text = line
	_title.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_subtitle.visible = true
	_subtitle.text = "YOU LOSE THE FIGHT"
	_score.visible = true
	_score.text = "Final: %d - %d" % [player_rounds, enemy_rounds]
	_prompt.visible = true
	_prompt.text = "Press Enter to try again"
	_awaiting_continue = true


func _show_round_win_splash() -> void:
	if _you_win_splash:
		_you_win_splash.play_splash()


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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_awaiting_continue = false
			continue_requested.emit()
			get_viewport().set_input_as_handled()
