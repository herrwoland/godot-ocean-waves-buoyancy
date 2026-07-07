extends Area3D
## Defines a region where ocean waves are damped (CALM) or the water surface is
## absent entirely (HOLE — eg. inside a tube/well going down through the sea).
##
## The footprint comes from a child CollisionShape3D (kept centered on this
## node), which doubles as the editor gizmo: BoxShape3D = box footprint,
## SphereShape3D/CylinderShape3D = circular footprint. The footprint is 2D in
## the XZ plane and extends infinitely vertically; only the node's yaw matters.
## The Area itself takes no part in physics (no layers, no monitoring).
##
## water.gd gathers all blockers each frame and feeds them to the water shader
## and to get_wave_height(), so visuals and gameplay always agree.

enum Mode { CALM, HOLE }

@export var mode: Mode = Mode.CALM
@export var fade_width: float = 8.0 # meters over which waves fade back to full height

var _is_box := false
var _radius := 5.0
var _half_extents := Vector2(5, 5)

func _ready() -> void:
	add_to_group(&'wave_blocker')
	# Purely a marker volume — never participate in physics.
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	refresh_from_shape()

## Reads the footprint from the first CollisionShape3D child. Call again if
## the shape is changed at runtime.
func refresh_from_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D and child.shape:
			var s: Shape3D = child.shape
			if s is BoxShape3D:
				_is_box = true
				_half_extents = Vector2(s.size.x, s.size.z) * 0.5
			elif s is SphereShape3D:
				_is_box = false
				_radius = s.radius
			elif s is CylinderShape3D:
				_is_box = false
				_radius = s.radius
			else:
				push_warning("WaveBlocker '%s': unsupported shape %s (use Box/Sphere/Cylinder)" % [name, s.get_class()])
			return
	push_warning("WaveBlocker '%s' has no CollisionShape3D child to define its footprint." % name)

## Signed distance from the footprint in the XZ plane (negative = inside).
## Must mirror wave_blocker_eval() in the water shader exactly.
func distance_xz(world_pos: Vector3) -> float:
	var rel := Vector2(world_pos.x - global_position.x, world_pos.z - global_position.z)
	if not _is_box:
		return rel.length() - _radius
	var c := cos(global_rotation.y)
	var s := sin(global_rotation.y)
	var local_p := Vector2(c * rel.x + s * rel.y, -s * rel.x + c * rel.y)
	var q := Vector2(absf(local_p.x), absf(local_p.y)) - _half_extents
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)

## 0 inside the footprint, rising to 1 across fade_width outside it.
func attenuation(world_pos: Vector3) -> float:
	return smoothstep(0.0, maxf(fade_width, 0.001), distance_xz(world_pos))

func contains(world_pos: Vector3) -> bool:
	return distance_xz(world_pos) <= 0.0

## Shader packing — a: (pos.x, pos.z, cos yaw, sin yaw)
func pack_a() -> Vector4:
	return Vector4(global_position.x, global_position.z, cos(global_rotation.y), sin(global_rotation.y))

## Shader packing — b: (half x / radius, half z, fade width, flags: +1 box, +2 hole)
func pack_b() -> Vector4:
	var flags := (1 if _is_box else 0) + (2 if mode == Mode.HOLE else 0)
	var half_x := _half_extents.x if _is_box else _radius
	return Vector4(half_x, _half_extents.y, fade_width, float(flags))
