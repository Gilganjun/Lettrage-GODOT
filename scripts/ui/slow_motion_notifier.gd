class_name SlowMotionNotifier
extends RefCounted

## Routes gameplay slow-mo events to the combat HUD banner.


static func notify() -> void:
	var hud := _find_combat_hud()
	if hud == null:
		return
	if hud.has_method("show_slow_motion_banner"):
		hud.show_slow_motion_banner()


static func _find_combat_hud() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var scene := tree.current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("UI/CombatHud")
