class_name Labyrinth
extends Node3D

## Symmetric labyrinth with concentric ring regions. Walls are deterministic
## given a seed. Connectors between adjacent rings alternate orientation so
## players cannot run straight through the maze.

const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 0.4
const SYMMETRY_ORDER := 12
const RING_RADII := [6.0, 12.0, 18.0, 24.0, 30.0, 36.0]
const CENTER_SQUARE_SIZE := 4.0

var seed_value: int = 0
var topology: Topology

var walls_root: Node3D
var floor_node: MeshInstance3D

func build(rng_seed: int, top: Topology) -> void:
	seed_value = rng_seed
	topology = top
	_resolve_children()
	_ensure_floor()
	_clear_walls()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for ring_index in RING_RADII.size():
		_build_ring(ring_index, rng)

func _resolve_children() -> void:
	walls_root = get_node_or_null("Walls") as Node3D
	if walls_root == null:
		walls_root = Node3D.new()
		walls_root.name = "Walls"
		add_child(walls_root)
	floor_node = get_node_or_null("Floor") as MeshInstance3D
	if floor_node == null:
		floor_node = MeshInstance3D.new()
		floor_node.name = "Floor"
		add_child(floor_node)

func _ensure_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(Topology.WIDTH, Topology.WIDTH)
	floor_node.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.11)
	mat.roughness = 0.95
	floor_node.material_override = mat

func _clear_walls() -> void:
	for child in walls_root.get_children():
		child.queue_free()

func _build_ring(ring_index: int, rng: RandomNumberGenerator) -> void:
	var radius: float = RING_RADII[ring_index]
	var segments := SYMMETRY_ORDER
	var gap_count := _gaps_for_ring(ring_index)
	var gap_indices := _choose_gap_indices(segments, gap_count, ring_index, rng)
	for s in segments:
		if gap_indices.has(s):
			continue
		var start_angle := TAU * (float(s) / float(segments))
		var end_angle := TAU * (float(s + 1) / float(segments))
		_add_arc_wall(radius, start_angle, end_angle)

func _gaps_for_ring(ring_index: int) -> int:
	# Inner rings open up more; outer rings keep more wall.
	return max(1, SYMMETRY_ORDER / (2 + ring_index))

func _choose_gap_indices(
	segments: int, gap_count: int, ring_index: int, rng: RandomNumberGenerator
) -> Array[int]:
	# Even rings start at offset 0, odd rings stagger by half a segment so the
	# connectors between rings do not line up. This produces the alternating
	# connector pattern.
	var stagger := 1 if ring_index % 2 == 1 else 0
	var step := max(1, segments / gap_count)
	var indices: Array[int] = []
	for k in gap_count:
		indices.append((k * step + stagger + rng.randi() % 2) % segments)
	return indices

func _add_arc_wall(radius: float, start_angle: float, end_angle: float) -> void:
	var subdivisions := 4
	for i in subdivisions:
		var a0 := lerp(start_angle, end_angle, float(i) / subdivisions)
		var a1 := lerp(start_angle, end_angle, float(i + 1) / subdivisions)
		var mid := (a0 + a1) * 0.5
		var p := Vector3(cos(mid) * radius, WALL_HEIGHT / 2.0, sin(mid) * radius)
		var length := 2.0 * radius * sin((a1 - a0) / 2.0)
		var wall := _make_wall(length)
		wall.position = p
		wall.rotation = Vector3(0, -mid - PI / 2.0, 0)
		walls_root.add_child(wall)

func _make_wall(length: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, WALL_HEIGHT, WALL_THICKNESS)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.22)
	mat.roughness = 0.85
	node.material_override = mat
	return node
