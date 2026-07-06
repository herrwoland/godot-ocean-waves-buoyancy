extends Area3D
## Detects the player arriving back at the shack after a completed delivery.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&'player') and GameState.phase == GameState.Phase.DELIVERED:
		GameState.set_phase(GameState.Phase.CAN_SLEEP)
		EventBus.returned_home.emit()
