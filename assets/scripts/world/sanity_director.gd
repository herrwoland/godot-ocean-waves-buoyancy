extends Node
## Applies the current day's strangeness to all SwappableProps. Transformations
## fire at transitions the player doesn't witness: waking up, and returning
## home from a trip (DESIGN.md §2).

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.returned_home.connect(_on_returned_home)

func _controller() -> Node:
	return get_tree().get_first_node_in_group(&'mission_controller')

func _on_day_started(_day: int) -> void:
	_apply(_controller().current_config().wake_swaps)

func _on_returned_home() -> void:
	_apply(_controller().current_config().return_home_swaps)

func _apply(swaps: Dictionary) -> void:
	if swaps.is_empty():
		return
	var max_tier := 0
	for prop in get_tree().get_nodes_in_group(&'swappable_prop'):
		if swaps.has(prop.prop_id):
			prop.apply_variant(swaps[prop.prop_id])
			max_tier = maxi(max_tier, swaps[prop.prop_id])
	if max_tier > 0:
		EventBus.strangeness_triggered.emit(max_tier)
