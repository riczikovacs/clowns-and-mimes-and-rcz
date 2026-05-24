extends "res://scripts/topology/topology.gd"

func kind() -> Kind:
	return Kind.PLANE

func name() -> String:
	return "plane"

func wrap(position: Vector3) -> Vector3:
	var h := half()
	return Vector3(clamp(position.x, -h, h), position.y, clamp(position.z, -h, h))

func distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
