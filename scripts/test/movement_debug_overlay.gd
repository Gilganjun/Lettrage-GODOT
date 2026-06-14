extends CanvasLayer

## Removable debug overlay — toggle with F3.

@export var level_path: NodePath = ^"../Level"

@onready var label: Label = $Panel/Label

var _visible := true


func _ready() -> void:
	visible = _visible
	label.text = "Debug overlay (F3 to toggle)"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_visible = not _visible
		visible = _visible


func _process(_delta: float) -> void:
	if not _visible:
		return
	var level := get_node_or_null(level_path)
	if level == null or not level.has_method("get_player"):
		return
	var player = level.get_player()
	if player == null or not player.has_method("get_debug_info"):
		return
	var info: Dictionary = player.get_debug_info()
	var state_names := ["IDLE", "RUN", "SPRINT", "JUMP", "FALL", "CLIMB"]
	var state: int = int(info.get("state", 0))
	label.text = (
		"Phase 2A Debug (F3)\n"
		+ "Pos: (%.1f, %.1f)\n" % [info["position"].x, info["position"].y]
		+ "Vel: (%.1f, %.1f)\n" % [info["velocity"].x, info["velocity"].y]
		+ "State: %s\n" % state_names[state]
		+ "Anim: %s\n" % info.get("animation", "?")
		+ "On floor: %s | On ladder: %s | Facing: %s"
		% [str(info.get("on_floor", false)), str(info.get("on_ladder", false)), info.get("facing", 1)]
	)
