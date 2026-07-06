extends Resource
## Data for one in-game day (DESIGN.md §2). The campaign is an array of these.

@export var day: int = 1
@export_multiline var letter_text: String = ""
@export var pickup_position: Vector3
@export var delivery_position: Vector3
