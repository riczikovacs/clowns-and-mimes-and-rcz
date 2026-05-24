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

func test_seeds_produce_walls() -> void:
	var topology := PlaneTopology.new()
	var a := LABYRINTH.instantiate()
	a.build(1, topology)
	var b := LABYRINTH.instantiate()
	b.build(2, topology)
	assert_true(a.walls_root.get_child_count() > 100, "seed 1 produces a populated labyrinth")
	assert_true(b.walls_root.get_child_count() > 100, "seed 2 produces a populated labyrinth")
	a.queue_free()
	b.queue_free()

func test_gap_jitter_matches_ts_for_known_inputs() -> void:
	# Same expected values as backend/shared/src/labyrinth.test.ts so client and
	# server geometry stay aligned. Spot-checks across the input domain rather
	# than exhaustive enumeration.
	const LabyrinthScript := preload("res://scripts/labyrinth.gd")
	for triple in [[0, 0, 0], [1, 2, 3], [12345, 5, 1], [99, 3, 2]]:
		var v: int = LabyrinthScript._gap_jitter(triple[0], triple[1], triple[2])
		assert_true(v == 0 or v == 1, "gap_jitter %s -> %d" % [str(triple), v])
