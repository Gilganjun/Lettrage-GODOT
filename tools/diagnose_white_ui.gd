extends SceneTree

## Lists large visible Controls/ColorRects/Sprites at runtime.
## godot --headless -s res://tools/diagnose_white_ui.gd

const MAIN_SCENE := "res://scenes/test/phase2c1_health_damage_test.tscn"
const MIN_AREA := 200000.0


func _initialize() -> void:
	var packed: PackedScene = load(MAIN_SCENE)
	var root: Node = packed.instantiate()
	root.name = "DiagRoot"
	get_root().add_child(root)
	await process_frame
	await process_frame
	print("=== Large visible drawables (area >= %.0f) ===" % MIN_AREA)
	_walk(root, "/root/DiagRoot")
	root.queue_free()
	quit(0)


func _walk(node: Node, path: String) -> void:
	if node is CanvasLayer:
		var layer := node as CanvasLayer
		print("[CanvasLayer] %s layer=%d" % [path, layer.layer])
	if node is Control:
		var c := node as Control
		if c.visible:
			var rect: Rect2 = c.get_global_rect()
			var area: float = rect.size.x * rect.size.y
			if area >= MIN_AREA:
				print("[Control] %s class=%s area=%.0f rect=%s" % [path, c.get_class(), area, rect])
	if node is ColorRect:
		var cr := node as ColorRect
		if cr.visible:
			var rect: Rect2 = cr.get_global_rect()
			print("[ColorRect] %s color=%s rect=%s" % [path, cr.color, rect])
	if node is Sprite2D:
		var sp := node as Sprite2D
		if sp.visible and sp.texture:
			var rect: Rect2 = sp.get_global_rect()
			var area: float = rect.size.x * rect.size.y
			if area >= MIN_AREA:
				var tex_path := sp.texture.resource_path if sp.texture.resource_path else str(sp.texture)
				print(
					"[Sprite2D] %s area=%.0f z=%d modulate=%s tex=%s"
					% [path, area, sp.z_index, sp.modulate, tex_path]
				)
	for child in node.get_children():
		_walk(child, "%s/%s" % [path, child.name])
