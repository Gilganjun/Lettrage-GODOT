class_name CollectiblePickupFlyFx
extends Control

## Player collectible pickup — pop to half-screen, then glide into the HUD slot.

const FONT := preload("res://assets/Panton-BlackCaps.otf")
const ENLARGE_SEC := 0.5
const FLY_SEC := 1.0
const PEAK_SCREEN_RATIO := 0.5
const PEAK_ALPHA := 0.5
const LABEL_GAP := 10.0
const LABEL_FONT_SIZE := 30

var _label: Label
var _visual_root: Node2D
var _reference_screen_size := 64.0


static func begin_player_pickup(
	pickup: Node2D,
	label_text: String,
	slot_id: String,
	reference_world_size: float,
) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	pickup.set_physics_process(false)
	play_for_player_pickup(pickup, label_text, slot_id, reference_world_size)
	pickup.queue_free()


static func play_for_player_pickup(
	pickup: Node2D,
	label_text: String,
	slot_id: String,
	reference_world_size: float = 64.0,
) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	var tree := pickup.get_tree()
	if tree == null:
		return
	var combat_hud := _find_combat_hud(pickup)
	if combat_hud == null:
		return
	var layer := _resolve_layer(combat_hud)
	if layer == null:
		return
	var viewport := pickup.get_viewport()
	if viewport == null:
		return
	var canvas_xf := viewport.get_canvas_transform()
	var start_screen: Vector2 = canvas_xf * pickup.global_position
	var target_screen: Vector2 = (
		combat_hud.get_player_collectible_slot_screen_position(slot_id)
		if combat_hud.has_method("get_player_collectible_slot_screen_position")
		else start_screen
	)
	var world_screen_scale := maxf(canvas_xf.get_scale().x, 0.001)
	var reference_screen_size := reference_world_size * world_screen_scale
	var visual := _duplicate_pickup_visual(pickup)
	var fx := CollectiblePickupFlyFx.new()
	layer.add_child(fx)
	fx._run(
		start_screen,
		target_screen,
		visual,
		label_text,
		reference_screen_size,
		viewport.get_visible_rect().size,
	)


static func _find_combat_hud(from: Node) -> Control:
	var scene := from.get_tree().current_scene
	if scene == null:
		return null
	var hud := scene.get_node_or_null("UI/CombatHud")
	return hud as Control if hud is Control else null


static func _resolve_layer(combat_hud: Control) -> Control:
	var layer := combat_hud.get_node_or_null("CollectibleFxLayer")
	if layer is Control:
		return layer as Control
	layer = combat_hud.get_node_or_null("DamageNumberLayer")
	return layer as Control if layer is Control else combat_hud


static func _duplicate_pickup_visual(pickup: Node2D) -> Node2D:
	var root := Node2D.new()
	for child in pickup.get_children():
		if child is Label:
			continue
		root.add_child(child.duplicate())
	return root


func _run(
	start_screen: Vector2,
	target_screen: Vector2,
	visual: Node2D,
	label_text: String,
	reference_screen_size: float,
	viewport_size: Vector2,
) -> void:
	_reference_screen_size = maxf(reference_screen_size, 8.0)
	mouse_filter = MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 48
	scale = Vector2.ONE
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	pivot_offset = Vector2.ZERO
	position = start_screen
	_build_visual(visual)
	_build_label(label_text)
	var bounds := _combined_local_bounds()
	pivot_offset = bounds.get_center()
	position = start_screen
	var peak_scale := _peak_scale_for(viewport_size)
	var dock_scale := _dock_scale_for(viewport_size)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * peak_scale, ENLARGE_SEC)
	tween.parallel().tween_property(self, "modulate:a", PEAK_ALPHA, ENLARGE_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_screen, FLY_SEC)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * dock_scale, FLY_SEC)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_dock_and_finish)


func _build_visual(visual: Node2D) -> void:
	_visual_root = visual
	_visual_root.position = Vector2.ZERO
	add_child(_visual_root)
	_center_visual(_visual_root)


func _build_label(label_text: String) -> void:
	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_label)
	_label.reset_size()
	var label_size := _label.get_combined_minimum_size()
	_label.custom_minimum_size = label_size
	_label.size = label_size
	var half_icon := _reference_screen_size * 0.5
	_label.position = Vector2(-label_size.x * 0.5, half_icon + LABEL_GAP)


func _center_visual(root: Node2D) -> void:
	var rect := _node2d_bounds(root)
	if rect.size == Vector2.ZERO:
		return
	root.position = -rect.get_center()


func _node2d_bounds(root: Node2D) -> Rect2:
	var bounds := Rect2()
	var started := false
	for child in root.get_children():
		if child is not Node2D:
			continue
		var node := child as Node2D
		var local_rect := _node_local_rect(node)
		var xf := node.get_transform()
		var p1 := xf * local_rect.position
		var p2 := xf * (local_rect.position + Vector2(local_rect.size.x, 0.0))
		var p3 := xf * (local_rect.position + Vector2(0.0, local_rect.size.y))
		var p4 := xf * (local_rect.position + local_rect.size)
		for p in [p1, p2, p3, p4]:
			if not started:
				bounds = Rect2(p, Vector2.ZERO)
				started = true
			else:
				bounds = bounds.expand(p)
	return bounds


func _node_local_rect(node: Node2D) -> Rect2:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture == null:
			return Rect2()
		var tex_size := sprite.texture.get_size()
		if sprite.centered:
			return Rect2(-tex_size * 0.5, tex_size)
		return Rect2(Vector2.ZERO, tex_size)
	if node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.is_empty():
			return Rect2()
		var min_p := poly.polygon[0]
		var max_p := poly.polygon[0]
		for p in poly.polygon:
			min_p = min_p.min(p)
			max_p = max_p.max(p)
		return Rect2(min_p, max_p - min_p)
	if node is Line2D:
		var line := node as Line2D
		if line.points.is_empty():
			return Rect2()
		var min_p := line.points[0]
		var max_p := line.points[0]
		for p in line.points:
			min_p = min_p.min(p)
			max_p = max_p.max(p)
		var pad := line.width * 0.5
		return Rect2(min_p - Vector2(pad, pad), max_p - min_p + Vector2(pad, pad) * 2.0)
	return Rect2(Vector2(-8.0, -8.0), Vector2(16.0, 16.0))


func _combined_local_bounds() -> Rect2:
	var started := false
	var bounds := Rect2()
	if _visual_root:
		var visual_bounds := _node2d_bounds(_visual_root)
		visual_bounds.position += _visual_root.position
		bounds = visual_bounds
		started = true
	if _label:
		var label_bounds := Rect2(_label.position, _label.size)
		bounds = label_bounds if not started else bounds.merge(label_bounds)
	return bounds


func _peak_scale_for(viewport_size: Vector2) -> float:
	var peak_size := minf(viewport_size.x, viewport_size.y) * PEAK_SCREEN_RATIO
	return peak_size / _reference_screen_size


func _dock_scale_for(viewport_size: Vector2) -> float:
	var dock_size := minf(viewport_size.x, viewport_size.y) * 0.06
	return clampf(dock_size / _reference_screen_size, 0.08, 0.22)


func _dock_and_finish() -> void:
	if _label and is_instance_valid(_label):
		_label.queue_free()
		_label = null
	if _visual_root and is_instance_valid(_visual_root):
		_visual_root.queue_free()
		_visual_root = null
	queue_free()
