class_name ActionAttackDefinition
extends Resource

## Data for cinematic ACTION attacks — plug in Kling animations later.

@export var attack_id: String = "Attack1"
@export var display_name: String = "Attack 1"
@export var animation_name: String = "Attack1"
@export var animation_fps: float = 24.0
@export var frame_count: int = 61
@export var frame_path_pattern: String = "res://assets/Characters/Player/Attack2/Attack2_%03d.png"
@export var native_frame_size: Vector2 = Vector2(316.0, 316.0)
@export var hit_frames: Array[int] = [17, 56, 91]
## Strike-point offsets from the frame center in native pixels (right-side contact art).
@export var hit_contact_offsets: Array[Vector2] = [
	Vector2(157.0, -12.0),
	Vector2(148.0, -62.0),
	Vector2(157.0, -67.0),
]
## Texture pixel coords of visible fist/foot sparks in 316x316 Attack1 frames.
@export var hit_vfx_pixels: Array[Vector2] = [
	Vector2(315.0, 101.0),
	Vector2(306.0, 96.0),
	Vector2(315.0, 90.0),
]
@export var hit_vfx_kinds: Array[String] = ["kick", "fist", "fist"]
@export var hit_damage: Array[int] = [4, 3, 3]
## Per-hit player side relative to enemy: 1 = left of enemy, -1 = right of enemy.
@export var hit_strike_sides: Array[int] = []
## Override horizontal standoff from player to enemy (0 = use controller default).
@export var strike_body_standoff: float = 0.0
@export var enemy_contact_offset: Vector2 = Vector2(0.0, -36.0)
@export var vfx_scale: float = 1.0
@export var vfx_particle_amount_scale: float = 1.0
@export var damage: int = 10
