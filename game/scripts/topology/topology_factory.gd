class_name TopologyFactory
extends Object

const PLANE_SCRIPT := preload("res://scripts/topology/plane_topology.gd")
const TORUS_SCRIPT := preload("res://scripts/topology/torus_topology.gd")
const KLEIN_SCRIPT := preload("res://scripts/topology/klein_topology.gd")
const SPHERE_SCRIPT := preload("res://scripts/topology/sphere_topology.gd")

static func create(kind: Topology.Kind) -> Topology:
	match kind:
		Topology.Kind.PLANE:
			return PLANE_SCRIPT.new()
		Topology.Kind.TORUS:
			return TORUS_SCRIPT.new()
		Topology.Kind.KLEIN:
			return KLEIN_SCRIPT.new()
		Topology.Kind.SPHERE:
			return SPHERE_SCRIPT.new()
	push_error("unknown topology")
	return PLANE_SCRIPT.new()

static func from_string(value: String) -> Topology:
	match value:
		"plane":
			return create(Topology.Kind.PLANE)
		"torus":
			return create(Topology.Kind.TORUS)
		"klein":
			return create(Topology.Kind.KLEIN)
		"sphere":
			return create(Topology.Kind.SPHERE)
	push_error("unknown topology string: %s" % value)
	return create(Topology.Kind.PLANE)
