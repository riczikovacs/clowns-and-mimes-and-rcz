extends Node3D

## Game arena. Generates the labyrinth, spawns players (one local plus bots in
## offline mode), runs the rules manager, and bridges all events to the HUD.

signal requested_screen(screen: String)

const PLAYER := preload("res://scenes/player.tscn")
const LABYRINTH := preload("res://scenes/labyrinth.tscn")
const GameRulesScript := preload("res://scripts/game_rules.gd")
const TopologyScript := preload("res://scripts/topology/topology.gd")
const TopologyFactory := preload("res://scripts/topology/topology_factory.gd")
const BotAIScript := preload("res://scripts/bot_ai.gd")
const AssetPaths := preload("res://scripts/asset_paths.gd")
const IN_GAME_MENU := preload("res://scenes/in_game_menu.tscn")

const BOT_COUNT_PER_TEAM := 3
const SPAWN_RADIUS := 2.5
const CONTACT_RADIUS := 1.2
const CONTACT_COOLDOWN_S := 0.6

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
var contact_cooldowns: Dictionary = {}
var menu: CanvasLayer = null

func _ready() -> void:
	topology = TopologyFactory.from_string(GameState.topology_as_string())
	_build_labyrinth()
	_setup_rules()
	_spawn_players()
	_setup_menu()
	hud.play_again_requested.connect(_on_play_again)
	hud.lobby_requested.connect(_on_back_to_menu)
	hud.set_sprint(100.0)
	hud.set_countdown_seconds(10.0)
	rules.start(topology)

func _setup_menu() -> void:
	menu = IN_GAME_MENU.instantiate()
	add_child(menu)
	menu.resume_requested.connect(_on_menu_resume)
	menu.quit_to_menu_requested.connect(_on_menu_quit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause") and not menu.visible:
		menu.open()
		get_viewport().set_input_as_handled()

func _on_menu_resume() -> void:
	menu.close()

func _on_menu_quit() -> void:
	menu.close()
	_on_back_to_menu()

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
	if is_bot:
		var ai := BotAIScript.new()
		p.add_child(ai)
		ai.attach(p, id, rules, topology)

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
	if not local_player.frozen:
		_check_contact_interactions()

func _check_contact_interactions() -> void:
	var active: String = rules.active_team()
	var now: float = Time.get_unix_time_from_system()
	for id in player_nodes.keys():
		if id == local_player_id:
			continue
		var node: Node = player_nodes[id]
		var d: float = topology.distance(local_player.global_position, node.global_position)
		if d > CONTACT_RADIUS:
			continue
		var last: float = contact_cooldowns.get(id, 0.0)
		if now - last < CONTACT_COOLDOWN_S:
			continue
		var info: Dictionary = rules.players[id]
		var triggered: bool = false
		if active == local_player.team and info["team"] != local_player.team and not info["frozen"]:
			triggered = rules.try_tag(local_player_id, id)
		elif info["team"] == local_player.team and info["frozen"]:
			triggered = rules.try_unfreeze(local_player_id, id)
		if triggered:
			contact_cooldowns[id] = now

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
	var victory: bool = team == local_player.team
	hud.show_end(victory)
	AudioBus.set_bus_volume("Music", -10.0)
	var stinger_path: String = AssetPaths.WIN_STINGER if victory else AssetPaths.LOSE_STINGER
	var stinger: AudioStream = AssetPaths.try_load_audio(stinger_path)
	if stinger == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stinger
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

const MIME_BATTLE_CRIES := [
	"MIMES- ATTACK!",
	"MIMES- STRIKE!",
	"MIMES- POUNCE!",
	"MIMES- ENTRAP!",
	"MIMES- BAFFLE!",
	"MIMES- SHUSH!",
	"MIMES- GLARE!",
	"MIMES- LUNGE!",
]

const CLOWN_BATTLE_CRIES := [
	"CLOWNS- ATTACK!",
	"CLOWNS- STRIKE!",
	"CLOWNS- HONK!",
	"CLOWNS- BOOP!",
	"CLOWNS- CACKLE!",
	"CLOWNS- CHARGE!",
	"CLOWNS- ROMP!",
	"CLOWNS- POUNCE!",
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
