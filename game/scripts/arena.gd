extends Node3D

## Game arena. Generates the labyrinth using the configured topology and seed,
## spawns the local player at the center, and drives the pre-game countdown.

signal requested_screen(screen: String)

const PLAYER := preload("res://scenes/player.tscn")
const LABYRINTH := preload("res://scenes/labyrinth.tscn")

@onready var world: Node3D = $World
@onready var spawn: Marker3D = $World/Spawn
@onready var labyrinth_holder: Node3D = $World/LabyrinthHolder
@onready var hud: CanvasLayer = $HUD

var local_player: Node = null
var topology: Topology
var labyrinth: Labyrinth = null

func _ready() -> void:
	topology = TopologyFactory.from_string(GameState.topology_as_string())
	_build_labyrinth()
	_spawn_local_player()
	hud.play_again_requested.connect(_on_play_again)
	hud.lobby_requested.connect(_on_back_to_menu)
	hud.set_sprint(100.0)
	hud.set_countdown_seconds(10.0)
	_run_pregame_countdown()

func _build_labyrinth() -> void:
	var node: Node = LABYRINTH.instantiate()
	labyrinth_holder.add_child(node)
	labyrinth = node as Labyrinth
	var rng_seed := _derive_seed()
	labyrinth.build(rng_seed, topology)

func _derive_seed() -> int:
	if GameState.lobby_code.is_empty():
		return randi()
	return GameState.lobby_code.hash() & 0x7fffffff

func _spawn_local_player() -> void:
	local_player = PLAYER.instantiate()
	local_player.team = "mime"
	world.add_child(local_player)
	local_player.global_position = spawn.global_position
	local_player.sprint_changed.connect(hud.set_sprint)

func _run_pregame_countdown() -> void:
	for s in range(10, 0, -1):
		hud.set_countdown_seconds(float(s))
		await get_tree().create_timer(1.0).timeout
	hud.set_countdown_seconds(60.0)
	hud.append_log("Free roam begins.")

func _on_play_again() -> void:
	requested_screen.emit("arena")

func _on_back_to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	requested_screen.emit("menu")

func _physics_process(_delta: float) -> void:
	if local_player == null or topology == null:
		return
	local_player.global_position = topology.wrap(local_player.global_position)
