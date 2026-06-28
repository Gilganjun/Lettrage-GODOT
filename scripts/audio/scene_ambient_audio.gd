extends AudioStreamPlayer

## Low-level scene-start ambient bed (GDevelop DepartScene PlaySound).

@export_range(0.0, 1.0, 0.01) var ambient_level := 0.2
@export var loop_track := true
@export var autostart := true


func _ready() -> void:
	volume_db = linear_to_db(clampf(ambient_level, 0.0, 1.0))
	if stream and loop_track:
		var playable := stream.duplicate()
		if playable is AudioStreamMP3:
			playable.loop = true
		stream = playable
	if autostart:
		play()
