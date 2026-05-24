extends TestCase

const W := Topology.WIDTH
const H := W / 2.0

func test_plane_clamps_to_bounds() -> void:
	var plane := PlaneTopology.new()
	var p := plane.wrap(Vector3(200, 0, -200))
	assert_eq(p.x, H, "plane clamp x")
	assert_eq(p.z, -H, "plane clamp z")

func test_plane_passes_inside_through() -> void:
	var plane := PlaneTopology.new()
	var p := plane.wrap(Vector3(5, 0, -7))
	assert_eq(p.x, 5.0, "inside x")
	assert_eq(p.z, -7.0, "inside z")

func test_torus_wraps_both_axes() -> void:
	var torus := TorusTopology.new()
	var p := torus.wrap(Vector3(H + 20.0, 0, 0))
	assert_approx(p.x, -H + 20.0, 0.001, "torus wrap x")
	var q := torus.wrap(Vector3(0, 0, -H - 20.0))
	assert_approx(q.z, H - 20.0, 0.001, "torus wrap z")

func test_torus_distance_takes_shortest_path() -> void:
	var torus := TorusTopology.new()
	var d := torus.distance(Vector3(-H + 5.0, 0, 0), Vector3(H - 5.0, 0, 0))
	assert_approx(d, 10.0, 0.001, "torus shortest distance")

func test_klein_flips_z_on_x_wrap() -> void:
	var klein := KleinTopology.new()
	var p := klein.wrap(Vector3(H + 20.0, 0, 20.0))
	assert_approx(p.x, -H + 20.0, 0.001, "klein wrap x")
	assert_approx(p.z, -20.0, 0.001, "klein flip z")

func test_sphere_reflects_outside_disk() -> void:
	var sphere := SphereTopology.new()
	var p := sphere.wrap(Vector3(H + 20.0, 0, 0))
	assert_true(absf(p.x) < H, "sphere returns inside disk")

func test_factory_returns_correct_kind() -> void:
	assert_eq(TopologyFactory.from_string("plane").kind(), Topology.Kind.PLANE)
	assert_eq(TopologyFactory.from_string("torus").kind(), Topology.Kind.TORUS)
	assert_eq(TopologyFactory.from_string("klein").kind(), Topology.Kind.KLEIN)
	assert_eq(TopologyFactory.from_string("sphere").kind(), Topology.Kind.SPHERE)
