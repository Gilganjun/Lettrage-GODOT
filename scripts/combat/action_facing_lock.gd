class_name ActionFacingLock
extends RefCounted

## Keeps ACTION attacker and defender sprites facing each other during cinematic sequences.


static func compute_facing_toward(body: Node2D, target: Node2D) -> int:
	if body == null or target == null:
		return 1
	return 1 if target.global_position.x >= body.global_position.x else -1


static func apply_facing(body: Node, sprite: AnimatedSprite2D, facing: int) -> void:
	if body != null and body.get("facing") != null:
		body.set("facing", facing)
	if sprite:
		sprite.flip_h = facing < 0


static func face_body_toward(body: Node, sprite: AnimatedSprite2D, target: Node2D) -> int:
	var facing := compute_facing_toward(body as Node2D, target)
	apply_facing(body, sprite, facing)
	return facing
