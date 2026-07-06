extends Label3D
## The ship's coordinate device: shows the vessel's live position in the
## fictional coordinate system. Attach as a child of the ship.

const CoordinateSystem := preload("res://assets/scripts/core/coordinate_system.gd")
const UPDATE_INTERVAL := 0.2

var _accumulator := 0.0

func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator < UPDATE_INTERVAL:
		return
	_accumulator = 0.0
	text = CoordinateSystem.format_position(global_position)
