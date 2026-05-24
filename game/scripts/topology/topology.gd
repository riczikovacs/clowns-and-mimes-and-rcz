class_name Topology
extends RefCounted

## Base class for topology adapters. A topology wraps positions and computes
## distances on the playing field. The XZ plane is the ground; Y is up.
## The domain is the centered square of side WIDTH.

const WIDTH := 80.0

enum Kind { PLANE, TORUS, KLEIN, SPHERE }

func kind() -> Kind:
	push_error("Topology.kind must be overridden")
	return Kind.PLANE

func wrap(position: Vector3) -> Vector3:
	push_error("Topology.wrap must be overridden")
	return position

func distance(a: Vector3, b: Vector3) -> float:
	push_error("Topology.distance must be overridden")
	var d := a - b
	d.y = 0.0
	return d.length()

func name() -> String:
	push_error("Topology.name must be overridden")
	return ""

static func half() -> float:
	return WIDTH / 2.0
