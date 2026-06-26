class_name PowerUpCollectSfx
extends RefCounted

## Random one-shot SFX when the player collects ACTION (Combat) or CLAW pickups.

const AUDIO_BASE := "res://assets/audio/PowerUps"
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]
const OVERLAP_SLOTS := 2
const DEFAULT_VOLUME_LINEAR := 0.55

enum Category { COMBAT, CLAW }

static var _cache: Dictionary = {}
static var _overlap_cursor := 0
static var _rng := RandomNumberGenerator.new()
static var _rng_ready := false


static func play_combat(host: Node, volume_linear: float = DEFAULT_VOLUME_LINEAR) -> void:
	_play(Category.COMBAT, host, volume_linear)


static func play_claw(host: Node, volume_linear: float = DEFAULT_VOLUME_LINEAR) -> void:
	_play(Category.CLAW, host, volume_linear)


static func _play(category: Category, host: Node, volume_linear: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	var tree := host.get_tree()
	if tree == null:
		return
	var pool: Array[AudioStream] = _sounds_for(category)
	if pool.is_empty():
		return
	_ensure_rng()
	var stream := pool[_rng.randi_range(0, pool.size() - 1)]
	var player := _acquire_player(_audio_bus(tree))
	if player == null:
		return
	player.volume_db = linear_to_db(clampf(volume_linear, 0.0, 1.0))
	player.stream = stream
	player.play()


static func _ensure_rng() -> void:
	if _rng_ready:
		return
	_rng.randomize()
	_rng_ready = true


static func _folder_for(category: Category) -> String:
	return "Combat" if category == Category.COMBAT else "Claw"


static func _sounds_for(category: Category) -> Array[AudioStream]:
	var key := int(category)
	if _cache.has(key):
		return _cache[key]
	var voices: Array[AudioStream] = []
	var dir_path := "%s/%s" % [AUDIO_BASE, _folder_for(category)]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("PowerUpCollectSfx: cannot open %s" % dir_path)
		_cache[key] = voices
		return voices
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.get_extension().to_lower() not in AUDIO_EXTENSIONS:
			continue
		var path := "%s/%s" % [dir_path, file_name]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			voices.append(stream)
	if voices.is_empty():
		push_warning("PowerUpCollectSfx: no clips in %s" % dir_path)
	_cache[key] = voices
	return voices


static func _audio_bus(tree: SceneTree) -> Node:
	var root := tree.current_scene
	if root == null:
		root = tree.root
	var bus := root.get_node_or_null("PowerUpCollectSfxBus")
	if bus == null:
		bus = Node.new()
		bus.name = "PowerUpCollectSfxBus"
		root.add_child(bus)
		for i in OVERLAP_SLOTS:
			var player := AudioStreamPlayer.new()
			player.name = "Slot%d" % i
			bus.add_child(player)
	return bus


static func _acquire_player(bus: Node) -> AudioStreamPlayer:
	var slots: Array[AudioStreamPlayer] = []
	for child in bus.get_children():
		if child is AudioStreamPlayer:
			slots.append(child as AudioStreamPlayer)
	if slots.is_empty():
		return null
	var player := slots[_overlap_cursor % slots.size()]
	_overlap_cursor = (_overlap_cursor + 1) % slots.size()
	if player.playing:
		player.stop()
	return player
