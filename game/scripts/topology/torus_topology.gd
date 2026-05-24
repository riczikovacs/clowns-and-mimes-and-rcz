class_name TorusTopology
extends Topology

func kind() -> Kind:
	return Kind.TORUS

func name() -> String:
	return "torus"

func wrap(position: Vector3) -> Vector3:
	return Vector3(_wrap(position.x), position.y, _wrap(position.z))

func distance(a: Vector3, b: Vector3) -> float:
	return Vector2(_wrapped_delta(a.x, b.x), _wrapped_delta(a.z, b.z)).length()

func _wrap(value: float) -> float:
	var h := half()
	var w := fposmod(value + h, WIDTH)
	return w - h

func _wrapped_delta(a: float, b: float) -> float:
	var d := fposmod(b - a, WIDTH)
	if d > WIDTH / 2.0:
		d -= WIDTH
	return d
