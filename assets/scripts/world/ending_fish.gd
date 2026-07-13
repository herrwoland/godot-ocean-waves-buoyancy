extends Area3D
## The fish waiting on the shore at the end of day 5 (DESIGN.md §2). Hovers
## gently in front of the shack; climbing on (interact) plays the ending.
## Hidden until the mission controller calls appear().

@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 0.8

@onready var _body: Node3D = $Body

var _base_body_y: float

func _ready() -> void:
	_base_body_y = _body.position.y
	set_active(false)

func appear() -> void:
	set_active(true)

func set_active(active: bool) -> void:
	visible = active
	set_deferred(&'monitorable', active)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred(&'disabled', not active)

func _process(_delta: float) -> void:
	if visible:
		_body.position.y = _base_body_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed * TAU) * bob_amplitude

func interact(player: Node) -> void:
	CutscenePlayer.play_ending(self, player)
