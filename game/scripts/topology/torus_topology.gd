extends "res://scripts/topology/topology.gd"

func kind() -> Kind:
	return Kind.TORUS

func name() -> String:
	return "torus"

func wrap(position: Vector3) -> Vector3:
	return Vector3(_wrap_axis(position.x), position.y, _wrap_axis(position.z))

func distance(a: Vector3, b: Vector3) -> float:
	return Vector2(_wrapped_delta(a.x, b.x), _wrapped_delta(a.z, b.z)).length()

func _wrap_axis(value: float) -> float:
	var h := half()
	var w := fposmod(value + h, WIDTH)
	return w - h

func _wrapped_delta(a: float, b: float) -> float:
	var d := fposmod(b - a, WIDTH)
	if d > WIDTH / 2.0:
		d -= WIDTH
	return d
