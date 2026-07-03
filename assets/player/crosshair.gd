extends Control
## Simple crosshair drawn at the center of the viewport.

@export var size_px: float = 8.0
@export var gap_px: float = 3.0
@export var thickness: float = 2.0
@export var color: Color = Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size / 2.0
	draw_line(center + Vector2(-size_px, 0), center + Vector2(-gap_px, 0), color, thickness)
	draw_line(center + Vector2(gap_px, 0), center + Vector2(size_px, 0), color, thickness)
	draw_line(center + Vector2(0, -size_px), center + Vector2(0, -gap_px), color, thickness)
	draw_line(center + Vector2(0, gap_px), center + Vector2(0, size_px), color, thickness)
