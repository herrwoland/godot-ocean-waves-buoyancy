extends Node3D
## Per-creature tuning for a hunter. Movement is driven by the
## CreatureDirector, which reads these values when this creature hunts.
## Adjust on the scene root (or per instance) to balance the chase.

@export var hunt_speed: float = 4.0 # m/s while chasing — the player swims 3.5
