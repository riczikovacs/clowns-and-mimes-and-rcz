extends Node3D

## Floats a 3D exclamation mark above frozen players. The local player never sees
## their own marker, even when frozen.

const HEIGHT_OFFSET := 0.9

@onready var stem: MeshInstance3D = $Stem
@onready var dot: MeshInstance3D = $Dot

func _ready() -> void:
	position.y = HEIGHT_OFFSET
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.0)
	mat.emission_energy_multiplier = 1.6
	stem.material_override = mat
	dot.material_override = mat

func _process(delta: float) -> void:
	rotate_y(delta * 1.4)
