class_name LevelGameplayConfig
extends Resource

@export var level_name: String = "Level 1"
@export var font_set_id: String = "original"
@export var rounds_to_win: int = 2
@export var match_rounds: int = 3
@export var round_countdown_seconds: float = 3.0
@export var fight_flash_duration: float = 2.0
@export var intro_drop_height: float = 1000.0
@export var intro_use_drop_top_y: bool = true
@export var intro_drop_top_y: float = -320.0
@export var intro_close_zoom_percent: float = 175.0
@export var intro_fall_ease_power: float = 1.35
@export var round_splash_lead_before_land: float = 2.0
@export var round_splash_duration: float = 2.0
@export var inter_round_countdown_seconds: float = 10.0
## Single-player: wait for Continue. Set true for multiplayer / 2-player timed advance.
@export var use_inter_round_countdown: bool = false
@export var post_action_round_result_delay: float = 1.0
@export var finisher_kill_cam_duration_sec: float = 3.0
@export_range(0.05, 1.0, 0.01) var finisher_kill_cam_slow_scale: float = 0.22
@export_range(0.35, 0.95, 0.01) var finisher_kill_cam_screen_fill: float = 0.52
@export var match_result_hold_seconds: float = 4.0
