class_name LetterSpawnProfile
extends Resource

## Tunable spawn settings shared by LetterSpawnDirector profiles.

enum ProfileKind {
	RAIN,
	LANE_RAIN,
}

@export var kind: ProfileKind = ProfileKind.RAIN
@export var spawn_interval: float = 0.3
@export var vowel_spawn_interval: float = 0.2
@export var spawn_x_min: float = 100.0
@export var spawn_x_max: float = 2000.0
@export var spawn_y: float = -256.0
@export var delete_y: float = 648.0
@export var delete_x_min: float = -64.0
@export var delete_x_max: float = 2336.0
@export var size_min: float = 25.0
@export var size_max: float = 50.0
@export var fall_speed_min: float = 120.0
@export var fall_speed_max: float = 210.0
@export var max_active_letters: int = 24
@export var min_spawn_spacing_x: float = 80.0
@export var spawn_spacing_retries: int = 3
@export var letter_lifetime: float = 10.0
@export var letter_fade_start: float = 8.0
@export var throttle_count_low: int = 10
@export var throttle_count_high: int = 20
@export var throttle_multiplier_mid: float = 2.0
@export var throttle_multiplier_high: float = 4.0

## Lane rain: three horizontal bands (fractions of spawn width).
@export var lane_vowel_end: float = 0.33
@export var lane_common_end: float = 0.66

const RARE_CONSONANTS := "QZXJK"
