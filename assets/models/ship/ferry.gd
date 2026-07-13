extends "res://assets/scripts/mass_calculation.gd"
## Root of the standalone ferry scene. The physics rig — buoyant cells, the
## hull drag volume and the collider — is invisible and must never be touched
## when changing the ship's look. Swap models by replacing the placeholders
## under the three visual sockets instead: ShipModel, WheelModel and the
## StairsModel node inside each ladder.
## The water node lives in the main scene, so it cannot be referenced from
## inside this scene file: the instance passes it in and we hand it to every
## buoyant cell here before the physics starts.

@export var water: Node

@onready var _engine_loop: AudioStreamPlayer3D = get_node_or_null(^'EngineLoop')

func _ready() -> void:
	for cell in buoyant_cells:
		cell.water = water
	super._ready()

## The engine only runs while someone is at the helm; throttle drives its
## volume and pitch so pushing the lever is audible, not just visible.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _engine_loop == null or _engine_loop.stream == null:
		return
	if piloted:
		if not _engine_loop.playing:
			_engine_loop.play()
		var effort := absf(helm_throttle)
		_engine_loop.volume_db = lerpf(-16.0, -4.0, effort)
		_engine_loop.pitch_scale = lerpf(0.9, 1.25, effort)
	elif _engine_loop.playing:
		_engine_loop.stop()
