extends "res://tests/test_case.gd"

const LABYRINTH := preload("res://scenes/labyrinth.tscn")
const PlaneTopology := preload("res://scripts/topology/plane_topology.gd")

func test_build_creates_walls_deterministically() -> void:
	var topology := PlaneTopology.new()
	var first := LABYRINTH.instantiate()
	first.build(12345, topology)
	var second := LABYRINTH.instantiate()
	second.build(12345, topology)
	assert_eq(
		first.walls_root.get_child_count(),
		second.walls_root.get_child_count(),
		"deterministic wall count"
	)
	first.queue_free()
	second.queue_free()

func test_different_seeds_produce_same_wall_count() -> void:
	var topology := PlaneTopology.new()
	var a := LABYRINTH.instantiate()
	a.build(1, topology)
	var b := LABYRINTH.instantiate()
	b.build(2, topology)
	assert_eq(
		a.walls_root.get_child_count(),
		b.walls_root.get_child_count(),
		"wall counts are stable across seeds"
	)
	a.queue_free()
	b.queue_free()
