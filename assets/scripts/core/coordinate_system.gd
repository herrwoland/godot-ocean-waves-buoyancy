extends Object
## Converts world XZ positions into the fictional coordinates shown on
## letters, packages and the ship's device (never raw engine units).

const ORIGIN_OFFSET := Vector2(4000.0, 7300.0)
const UNIT_SCALE := 0.1

static func format_position(world_pos: Vector3) -> String:
	var north := ORIGIN_OFFSET.x + world_pos.x * UNIT_SCALE
	var west := ORIGIN_OFFSET.y - world_pos.z * UNIT_SCALE
	return "%07.1f N  %07.1f W" % [north, west]
