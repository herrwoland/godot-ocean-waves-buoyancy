extends Node3D
## Keeps the rain emitter/collider centered on the camera horizontally, at a fixed
## height, without inheriting the camera's rotation (which would tilt the emission box).

@export var target: Node3D
@export var height_offset: float = 50.0

func _process(_delta: float) -> void:
	if not target:
		return
	global_position = Vector3(target.global_position.x, height_offset, target.global_position.z)
