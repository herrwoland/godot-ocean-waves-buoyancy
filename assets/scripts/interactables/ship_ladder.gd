extends Area3D
## Boarding ladder on the ship's hull. When the player is in its volume (usually
## while swimming beside the ship) and holds jump/space, it hauls them up onto
## the deck at `deck_point` — same key as swimming up, so a panicked player
## spamming space climbs out. Carrying is preserved, so the package comes too.

@export var deck_point: Node3D

var _player: Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&'player'):
		_player = body

func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null

func _physics_process(_delta: float) -> void:
	if _player and Input.is_action_pressed(&'jump'):
		_player.request_climb(deck_point.global_position)
