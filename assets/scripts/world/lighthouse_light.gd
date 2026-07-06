extends Node3D
## Rotates the lighthouse lamp pivot so the beam sweeps the horizon.

@export var rotation_speed: float = 0.35 # radians/sec

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)
