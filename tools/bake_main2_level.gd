extends SceneTree

const OUT_PATH := "res://scenes/levels/main2_heallthbartest_level.tscn"
const Baker := preload("res://scripts/level/gdevelop_level_baker.gd")


func _initialize() -> void:
	print("=== Bake Main2_heallthbartest Level ===")
	var root: Node2D = Baker.build()
	print("[INFO] Root children: %d" % root.get_child_count())
	_assign_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("PackedScene.pack failed: %d" % pack_err)
		quit(1)
		return
	var save_err := ResourceSaver.save(packed, OUT_PATH)
	if save_err != OK:
		push_error("ResourceSaver.save failed: %d" % save_err)
		quit(1)
		return
	print("[OK] Saved %s" % OUT_PATH)
	print("[INFO] Open this scene in Godot 2D editor for manual layout editing.")
	quit(0)


func _assign_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		_assign_owner_recursive(child, owner)
