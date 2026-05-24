class_name SphereTopology
extends Topology

## Stereographic-style sphere: the canonical domain is a disk. Outside the disk
## positions reflect back to their antipode, modeling a finite spherical surface.

func kind() -> Kind:
	return Kind.SPHERE

func name() -> String:
	return "sphere"

func wrap(position: Vector3) -> Vector3:
	var h := half()
	var r := Vector2(position.x, position.z).length()
	if r <= h:
		return position
	var k := (WIDTH - r) / r
	return Vector3(position.x * k, position.y, position.z * k)

func distance(a: Vector3, b: Vector3) -> float:
	var h := half()
	var ax := (a.x / h) * PI
	var az := (a.z / h) * PI
	var bx := (b.x / h) * PI
	var bz := (b.z / h) * PI
	var dx := cos(ax) * cos(az) - cos(bx) * cos(bz)
	var dy := sin(ax) * cos(az) - sin(bx) * cos(bz)
	var dz := sin(az) - sin(bz)
	var chord_sq: float = dx * dx + dy * dy + dz * dz
	chord_sq = clamp(chord_sq, 0.0, 4.0)
	return h * acos(1.0 - chord_sq / 2.0)
