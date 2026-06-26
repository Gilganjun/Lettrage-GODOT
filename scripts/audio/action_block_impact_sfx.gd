class_name ActionBlockImpactSfx
extends RefCounted

## Random ImpactSFX one-shots when an ACTION strike is blocked during a combo.

const AUDIO_DIR := "res://assets/audio/ImpactSFX"
const AUDIO_EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]
const OVERLAP_SLOTS := 3
const DEFAULT_VOLUME_LINEAR := 0.48

static var _cache: Array[AudioStream] = []
static var _cache_ready := false
static var _overlap_cursor := 0
static var _rng := RandomNumberGenerator.new()
static var _rng_ready := false


static func play(host: Node, volume_linear: float = DEFAULT_VOLUME_LINEAR) -> void:
	if host == null or not is_instance_valid(host):
		return
	var tree := host.get_tree()
	if tree == null:
		return
	var pool := _sounds()
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


static func _sounds() -> Array[AudioStream]:
	if _cache_ready:
		return _cache
	_cache.clear()
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		push_warning("ActionBlockImpactSfx: cannot open %s" % AUDIO_DIR)
		_cache_ready = true
		return _cache
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if file_name.get_extension().to_lower() not in AUDIO_EXTENSIONS:
			continue
		var path := "%s/%s" % [AUDIO_DIR, file_name]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream != null:
			_cache.append(stream)
	if _cache.is_empty():
		push_warning("ActionBlockImpactSfx: no clips in %s" % AUDIO_DIR)
	_cache_ready = true
	return _cache


static func _audio_bus(tree: SceneTree) -> Node:
	var root := tree.current_scene
	if root == null:
		root = tree.root
	var bus := root.get_node_or_null("ActionBlockImpactSfxBus")
	if bus == null:
		bus = Node.new()
		bus.name = "ActionBlockImpactSfxBus"
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
