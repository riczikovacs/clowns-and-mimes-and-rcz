extends Node3D

## Symmetric labyrinth with concentric ring regions. Walls are deterministic
## given a seed, alternate connector orientation between rings, are solid
## colliders, and feed an AStarGrid2D for bot pathfinding.

const TopologyScript := preload("res://scripts/topology/topology.gd")

const WALL_HEIGHT := 6.0
const WALL_THICKNESS := 0.4
const SYMMETRY_ORDER := 12
const RING_RADII: Array[float] = [6.0, 12.0, 18.0, 24.0, 30.0, 36.0]
const CENTER_SQUARE_SIZE := 4.0

const GRID_RES := 80
const CELL_SIZE := TopologyScript.WIDTH / float(GRID_RES)
const PLAYER_CLEARANCE := 0.55

var seed_value: int = 0
var topology: TopologyScript
var pathfinder: AStarGrid2D

var walls_root: Node3D
var floor_node: MeshInstance3D
var _wall_segments: Array = []  # [{transform, length}, ...]

func build(rng_seed: int, top: TopologyScript) -> void:
	seed_value = rng_seed
	topology = top
	_resolve_children()
	_ensure_floor()
	_clear_walls()
	_wall_segments.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for ring_index in RING_RADII.size():
		_build_ring(ring_index, rng)
	_build_pathfinder()

func find_path(from: Vector3, to: Vector3) -> Array[Vector3]:
	if pathfinder == null:
		return []
	var from_cell: Vector2i = _world_to_cell(from)
	var to_cell: Vector2i = _world_to_cell(to)
	if pathfinder.is_point_solid(to_cell):
		# Target sits inside a wall - nudge to the nearest open cell.
		to_cell = _nearest_open_cell(to_cell)
	if pathfinder.is_point_solid(from_cell):
		from_cell = _nearest_open_cell(from_cell)
	var raw: PackedVector2Array = pathfinder.get_point_path(from_cell, to_cell)
	var out: Array[Vector3] = []
	for point in raw:
		out.append(_cell_to_world(Vector2i(int(point.x), int(point.y))))
	return out

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

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
	plane.size = Vector2(TopologyScript.WIDTH, TopologyScript.WIDTH)
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
	var segments: int = SYMMETRY_ORDER
	var gap_count: int = _gaps_for_ring(ring_index)
	var gap_indices: Array[int] = _choose_gap_indices(segments, gap_count, ring_index, rng)
	for s in segments:
		if gap_indices.has(s):
			continue
		var start_angle: float = TAU * (float(s) / float(segments))
		var end_angle: float = TAU * (float(s + 1) / float(segments))
		_add_arc_wall(radius, start_angle, end_angle)

func _gaps_for_ring(ring_index: int) -> int:
	# Inner rings open up more; outer rings keep more wall.
	return max(1, SYMMETRY_ORDER / (2 + ring_index))

func _choose_gap_indices(
	segments: int, gap_count: int, ring_index: int, rng: RandomNumberGenerator
) -> Array[int]:
	# Even rings start at offset 0, odd rings stagger by one segment so the
	# connectors between rings do not line up. This produces the alternating
	# connector pattern.
	var stagger: int = 1 if ring_index % 2 == 1 else 0
	var step: int = max(1, segments / gap_count)
	var indices: Array[int] = []
	for k in gap_count:
		indices.append((k * step + stagger + rng.randi() % 2) % segments)
	return indices

func _add_arc_wall(radius: float, start_angle: float, end_angle: float) -> void:
	var subdivisions: int = 4
	for i in subdivisions:
		var t0: float = float(i) / float(subdivisions)
		var t1: float = float(i + 1) / float(subdivisions)
		var a0: float = lerpf(start_angle, end_angle, t0)
		var a1: float = lerpf(start_angle, end_angle, t1)
		var mid: float = (a0 + a1) * 0.5
		var p := Vector3(cos(mid) * radius, WALL_HEIGHT / 2.0, sin(mid) * radius)
		var seg_length: float = 2.0 * radius * sin((a1 - a0) / 2.0)
		var wall: StaticBody3D = _make_wall(seg_length)
		wall.position = p
		wall.rotation = Vector3(0.0, -mid - PI / 2.0, 0.0)
		walls_root.add_child(wall)
		_wall_segments.append({"transform": wall.transform, "length": seg_length})

func _make_wall(seg_length: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1  # Layer 1 so the default CharacterBody3D mask collides.
	body.collision_mask = 0
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(seg_length, WALL_HEIGHT, WALL_THICKNESS)
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.22)
	mat.roughness = 0.85
	mesh_node.material_override = mat
	body.add_child(mesh_node)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(seg_length, WALL_HEIGHT, WALL_THICKNESS)
	collider.shape = shape
	body.add_child(collider)
	return body

# ---------------------------------------------------------------------------
# Pathfinding grid
# ---------------------------------------------------------------------------

func _build_pathfinder() -> void:
	pathfinder = AStarGrid2D.new()
	pathfinder.region = Rect2i(0, 0, GRID_RES, GRID_RES)
	pathfinder.cell_size = Vector2.ONE
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	pathfinder.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	pathfinder.update()
	for segment in _wall_segments:
		_mark_wall_solid(segment["transform"], segment["length"])

func _mark_wall_solid(wall_xform: Transform3D, seg_length: float) -> void:
	var half_len: float = seg_length * 0.5 + PLAYER_CLEARANCE
	var half_thick: float = WALL_THICKNESS * 0.5 + PLAYER_CLEARANCE
	var inverse: Transform3D = wall_xform.affine_inverse()
	# World-space AABB of the inflated wall for fast cell-range culling.
	var min_pos := Vector3(INF, 0.0, INF)
	var max_pos := Vector3(-INF, 0.0, -INF)
	for dx in [-half_len, half_len]:
		for dz in [-half_thick, half_thick]:
			var w: Vector3 = wall_xform * Vector3(dx, 0.0, dz)
			min_pos.x = min(min_pos.x, w.x)
			min_pos.z = min(min_pos.z, w.z)
			max_pos.x = max(max_pos.x, w.x)
			max_pos.z = max(max_pos.z, w.z)
	var min_cell: Vector2i = _world_to_cell(min_pos)
	var max_cell: Vector2i = _world_to_cell(max_pos)
	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(cx, cy)
			var world_point: Vector3 = _cell_to_world(cell)
			var local: Vector3 = inverse * world_point
			if absf(local.x) <= half_len and absf(local.z) <= half_thick:
				pathfinder.set_point_solid(cell, true)

func _world_to_cell(p: Vector3) -> Vector2i:
	var half: float = TopologyScript.WIDTH * 0.5
	var x: int = int(round((p.x + half) / CELL_SIZE))
	var y: int = int(round((p.z + half) / CELL_SIZE))
	return Vector2i(clamp(x, 0, GRID_RES - 1), clamp(y, 0, GRID_RES - 1))

func _cell_to_world(cell: Vector2i) -> Vector3:
	var half: float = TopologyScript.WIDTH * 0.5
	var x: float = float(cell.x) * CELL_SIZE - half + CELL_SIZE * 0.5
	var z: float = float(cell.y) * CELL_SIZE - half + CELL_SIZE * 0.5
	return Vector3(x, 0.0, z)

func _nearest_open_cell(cell: Vector2i) -> Vector2i:
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if c.x < 0 or c.x >= GRID_RES or c.y < 0 or c.y >= GRID_RES:
					continue
				if not pathfinder.is_point_solid(c):
					return c
	return cell
