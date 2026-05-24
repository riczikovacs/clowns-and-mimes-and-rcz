class_name KleinTopology
extends Topology

## Klein bottle: X axis wraps with a Z flip, Z axis wraps without flip.

func kind() -> Kind:
	return Kind.KLEIN

func name() -> String:
	return "klein"

func wrap(position: Vector3) -> Vector3:
	var h := half()
	var wrapped_x := fposmod(position.x + h, WIDTH) - h
	var x_crossings := int(floor((position.x + h) / WIDTH))
	var flipped := (x_crossings % 2) != 0
	var z0 := -position.z if flipped else position.z
	var wrapped_z := fposmod(z0 + h, WIDTH) - h
	return Vector3(wrapped_x, position.y, wrapped_z)

func distance(a: Vector3, b: Vector3) -> float:
	var dx := _wrapped_delta(a.x, b.x)
	var flipped := absf(a.x - b.x) > WIDTH / 2.0
	var bz := -b.z if flipped else b.z
	var dz := _wrapped_delta(a.z, bz)
	return Vector2(dx, dz).length()

func _wrapped_delta(a: float, b: float) -> float:
	var d := fposmod(b - a, WIDTH)
	if d > WIDTH / 2.0:
		d -= WIDTH
	return d
