extends Node3D
## Per-creature tuning for a hunter. Movement is driven by the
## CreatureDirector, which reads these values when this creature hunts.
## Adjust on the scene root (or per instance) to balance the chase.
## The current model is ~160 m long with its mouth ~34 m ahead of the origin,
## so distances here are mouth-relative, not origin-relative.

@export var hunt_speed: float = 9.0 # m/s while chasing — the player swims 3.5
@export var kill_distance: float = 12.0 # how close the mouth must get to bite
@export var carry_speed: float = 8.0 # m/s while dragging the catch into the deep
@export var jaw: Node3D # opens for the attack; found in the model if left unset

var _jaw_closed_x := 0.0
var _jaw_tween: Tween

func _ready() -> void:
	if jaw == null:
		jaw = get_node_or_null(^'Mesh/fish_01/jaw')
	if jaw:
		_jaw_closed_x = jaw.rotation.x # the authored rest pose is the closed jaw

## The jaw swings open (x rotation 0) when the hunt begins and clamps back to
## its rest pose on the bite or when the prey escapes.
func set_jaw_open(open: bool) -> void:
	if jaw == null:
		return
	if _jaw_tween:
		_jaw_tween.kill()
	_jaw_tween = create_tween()
	_jaw_tween.tween_property(jaw, "rotation:x", 0.0 if open else _jaw_closed_x, 0.6 if open else 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## World position of the mouth — kills and carrying anchor here, because the
## body's origin sits a long way behind the snout on this model.
func mouth_position() -> Vector3:
	return jaw.global_position if jaw else global_position
