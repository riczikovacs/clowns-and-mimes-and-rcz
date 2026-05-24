extends Node3D

## Game arena. Generates the labyrinth, spawns players (one local plus bots in
## offline mode), runs the rules manager, and bridges all events to the HUD.

signal requested_screen(screen: String)

const PLAYER := preload("res://scenes/player.tscn")
const LABYRINTH := preload("res://scenes/labyrinth.tscn")
const GameRulesScript := preload("res://scripts/game_rules.gd")
const TopologyScript := preload("res://scripts/topology/topology.gd")
const TopologyFactory := preload("res://scripts/topology/topology_factory.gd")

const BOT_COUNT_PER_TEAM := 3
const SPAWN_RADIUS := 2.5

@onready var world: Node3D = $World
@onready var spawn: Marker3D = $World/Spawn
@onready var labyrinth_holder: Node3D = $World/LabyrinthHolder
@onready var hud: CanvasLayer = $HUD

var local_player: Node = null
var local_player_id: String = ""
var topology: TopologyScript
var labyrinth: Node3D = null
var rules: Node = null
var player_nodes: Dictionary = {}

func _ready() -> void:
	topology = TopologyFactory.from_string(GameState.topology_as_string())
	_build_labyrinth()
	_setup_rules()
	_spawn_players()
	hud.play_again_requested.connect(_on_play_again)
	hud.lobby_requested.connect(_on_back_to_menu)
	hud.set_sprint(100.0)
	hud.set_countdown_seconds(10.0)
	rules.start(topology)

func _build_labyrinth() -> void:
	var node: Node3D = LABYRINTH.instantiate()
	labyrinth_holder.add_child(node)
	labyrinth = node
	labyrinth.build(_derive_seed(), topology)

func _derive_seed() -> int:
	if GameState.lobby_code.is_empty():
		return randi()
	return GameState.lobby_code.hash() & 0x7fffffff

func _setup_rules() -> void:
	rules = GameRulesScript.new()
	add_child(rules)
	rules.topology = topology
	rules.tagged.connect(_on_tagged)
	rules.saved.connect(_on_saved)
	rules.won.connect(_on_won)
	rules.phase_changed.connect(_on_phase_changed)

func _spawn_players() -> void:
	GameState.ensure_username()
	var local_team := "mime"
	local_player_id = "local"
	_spawn_player(local_player_id, GameState.username, local_team, false, true)
	for i in BOT_COUNT_PER_TEAM - 1:
		_spawn_player("mime_bot_%d" % i, _bot_name(), "mime", true, false)
	for i in BOT_COUNT_PER_TEAM:
		_spawn_player("clown_bot_%d" % i, _bot_name(), "clown", true, false)
	_render_team_status()

func _spawn_player(id: String, p_name: String, team: String, is_bot: bool, is_local: bool) -> void:
	var p: Node = PLAYER.instantiate()
	p.team = team
	p.bot = is_bot
	p.is_local = is_local
	p.display_name = p_name
	world.add_child(p)
	var origin := spawn.global_position
	var angle := randf() * TAU
	var radius := randf() * SPAWN_RADIUS
	var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	p.global_position = origin + offset
	rules.register_player(id, team, p.global_position, p_name, is_bot)
	player_nodes[id] = p
	if is_local:
		local_player = p
		p.sprint_changed.connect(hud.set_sprint)
		p.frozen_changed.connect(_on_local_frozen_changed)

func _bot_name() -> String:
	return UsernameGenerator.generate()

func _process(_delta: float) -> void:
	if rules == null:
		return
	for id in player_nodes.keys():
		var node: Node = player_nodes[id]
		rules.update_position(id, node.global_position)
	rules.tick(Time.get_unix_time_from_system())
	hud.set_countdown_seconds(rules.phase_time_remaining(Time.get_unix_time_from_system()))

func _physics_process(_delta: float) -> void:
	if local_player == null or topology == null:
		return
	local_player.global_position = topology.wrap(local_player.global_position)
	if Input.is_action_just_pressed("action_tag") and not local_player.frozen:
		_try_local_interaction()

func _try_local_interaction() -> void:
	var active := rules.active_team()
	for id in player_nodes.keys():
		if id == local_player_id:
			continue
		var node: Node = player_nodes[id]
		var d := topology.distance(local_player.global_position, node.global_position)
		var info: Dictionary = rules.players[id]
		if d > 1.6:
			continue
		if active == local_player.team and info["team"] != local_player.team and not info["frozen"]:
			rules.try_tag(local_player_id, id)
			return
		if info["team"] == local_player.team and info["frozen"]:
			rules.try_unfreeze(local_player_id, id)
			return

func _on_tagged(victim_id: String, attacker_id: String, team: String) -> void:
	var victim: Node = player_nodes.get(victim_id)
	if victim != null:
		victim.frozen = true
	var attacker_info: Dictionary = rules.players.get(attacker_id, {})
	var victim_info: Dictionary = rules.players.get(victim_id, {})
	var verb := "mimed" if team == "mime" else "clowned"
	hud.append_log("%s was %s by %s" % [victim_info.get("name", "?"), verb, attacker_info.get("name", "?")])
	if victim_id == local_player_id:
		hud.flash_frozen(team, attacker_info.get("name", "?"))
	_render_team_status()

func _on_saved(victim_id: String, savior_id: String) -> void:
	var victim: Node = player_nodes.get(victim_id)
	if victim != null:
		victim.frozen = false
	var savior_info: Dictionary = rules.players.get(savior_id, {})
	var victim_info: Dictionary = rules.players.get(victim_id, {})
	hud.append_log("%s saved %s" % [savior_info.get("name", "?"), victim_info.get("name", "?")])
	if victim_id == local_player_id:
		hud.clear_frozen_overlay()
	_render_team_status()

func _on_won(team: String) -> void:
	var victory := (team == local_player.team)
	hud.show_end(victory)
	AudioBus.set_bus_volume("Music", 0.0)
	# Audio stingers attach in the polish phase once assets are vendored.

const MIME_BATTLE_CRIES := [
	"MIMES- ATTACK!",
	"MIMES- POUNCE IN SILENCE!",
	"MIMES- ENTRAP THEM!",
	"MIMES- STRIKE!",
	"MIMES- THE STAGE IS YOURS!",
]

const CLOWN_BATTLE_CRIES := [
	"CLOWNS- ATTACK!",
	"CLOWNS- HONK THEIR DOOM!",
	"CLOWNS- PILE ON!",
	"CLOWNS- UNLEASH THE BIG TOP!",
	"CLOWNS- BRING THE LAUGHS!",
]

func _on_phase_changed(phase: int) -> void:
	match phase:
		GameRulesScript.Phase.FREE_ROAM:
			hud.append_log("Free roam begins.")
		GameRulesScript.Phase.TURN_MIME:
			hud.append_log(MIME_BATTLE_CRIES[randi() % MIME_BATTLE_CRIES.size()])
		GameRulesScript.Phase.TURN_CLOWN:
			hud.append_log(CLOWN_BATTLE_CRIES[randi() % CLOWN_BATTLE_CRIES.size()])

func _on_local_frozen_changed(is_frozen: bool) -> void:
	if not is_frozen:
		hud.clear_frozen_overlay()

func _render_team_status() -> void:
	var list: Array = []
	for player in rules.players.values():
		list.append(player)
	hud.render_team_status(list)

func _on_play_again() -> void:
	requested_screen.emit("arena")

func _on_back_to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	requested_screen.emit("menu")
