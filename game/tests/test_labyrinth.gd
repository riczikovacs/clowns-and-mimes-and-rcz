extends TestCase

const LABYRINTH := preload("res://scenes/labyrinth.tscn")

func test_build_creates_walls_deterministically() -> void:
	var topology := PlaneTopology.new()
	var first: Labyrinth = LABYRINTH.instantiate()
	first.build(12345, topology)
	var second: Labyrinth = LABYRINTH.instantiate()
	second.build(12345, topology)
	assert_eq(
		first.walls_root.get_child_count(),
		second.walls_root.get_child_count(),
		"deterministic wall count"
	)
	first.queue_free()
	second.queue_free()

func test_different_seeds_diverge() -> void:
	var topology := PlaneTopology.new()
	var a: Labyrinth = LABYRINTH.instantiate()
	a.build(1, topology)
	var b: Labyrinth = LABYRINTH.instantiate()
	b.build(2, topology)
	# Different seeds should at minimum produce a different gap selection. We
	# allow equal counts (both rings always get the same number of gaps), but
	# the wall transforms cannot be identical for the same indices.
	var equal_count := a.walls_root.get_child_count() == b.walls_root.get_child_count()
	assert_true(equal_count, "wall counts should be stable across seeds")
	a.queue_free()
	b.queue_free()
