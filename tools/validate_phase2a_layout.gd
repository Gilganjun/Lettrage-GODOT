extends SceneTree

const LAYOUT_SCENE := "res://scenes/test/phase2a_layout_verification.tscn"
const TRANSFORMS := "res://resources/phase2a/instance_transforms.json"
const FAILED_SCENE := "res://scenes/test/phase2a_movement_test_failed.tscn"

var _errors: Array[String] = []


func _initialize() -> void:
	print("=== Phase 2A Layout Verification — Syntax Validation ===")
	_check_files()
	_load_scene(LAYOUT_SCENE, "Static layout verification")
	_load_scene(FAILED_SCENE, "Failed movement test (preserved)")
	_print_summary()
	quit(0 if _errors.is_empty() else 1)


func _check_files() -> void:
	for path in [
		"res://scripts/conversion/gdevelop_transform.gd",
		TRANSFORMS,
		LAYOUT_SCENE,
		FAILED_SCENE,
	]:
		if FileAccess.file_exists(path):
			print("[OK] %s" % path)
		else:
			_fail("%s missing" % path)
	var text := FileAccess.get_file_as_string(TRANSFORMS)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY:
		_fail("instance_transforms.json invalid")
	else:
		var count: int = data.get("visual_instances", []).size()
		print("[OK] %d visual instances in transform JSON" % count)
	print("[INFO] Transform/visual validation: PENDING MANUAL")
	print("[INFO] Collision alignment: NOT STARTED")
	print("[INFO] Phase 2A NOT marked complete")


func _load_scene(path: String, label: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("Could not load %s" % label)
		return
	var node := packed.instantiate()
	if node == null:
		_fail("Could not instantiate %s" % label)
		return
	print("[OK] %s instantiates" % label)
	node.free()


func _fail(msg: String) -> void:
	_errors.append(msg)
	print("[FAIL] %s" % msg)


func _print_summary() -> void:
	print("\n=== Summary: %d syntax errors ===" % _errors.size())
	if _errors.is_empty():
		print("Syntax validation PASSED — manual visual validation still required")
