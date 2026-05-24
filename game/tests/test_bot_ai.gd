extends "res://tests/test_case.gd"

const BotAIScript := preload("res://scripts/bot_ai.gd")
const GameRulesScript := preload("res://scripts/game_rules.gd")
const PlaneTopology := preload("res://scripts/topology/plane_topology.gd")

func _make_setup() -> Dictionary:
	var topology := PlaneTopology.new()
	var rules := GameRulesScript.new()
	rules.topology = topology
	var player := CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.team = "mime"
	player.bot = true
	player.is_local = false
	player.global_position = Vector3.ZERO
	var ai := BotAIScript.new()
	ai.attach(player, "self", rules, topology)
	rules.register_player("self", "mime", Vector3.ZERO, "self", true)
	return {"rules": rules, "ai": ai, "player": player, "topology": topology}

func test_chase_state_when_enemy_visible_during_own_turn() -> void:
	var ctx := _make_setup()
	var rules: Node = ctx["rules"]
	var ai: Node = ctx["ai"]
	rules.register_player("e", "clown", Vector3(5.0, 0.0, 0.0), "E", true)
	rules.phase = GameRulesScript.Phase.TURN_MIME
	ai._choose_state()
	assert_eq(ai.state, BotAIScript.State.CHASE, "chase enemy on own turn")
	ai._choose_target()
	assert_approx(ai.patrol_target.x, 5.0, 0.001, "target is enemy position")

func test_flee_state_during_opponent_turn() -> void:
	var ctx := _make_setup()
	var rules: Node = ctx["rules"]
	var ai: Node = ctx["ai"]
	rules.register_player("e", "clown", Vector3(5.0, 0.0, 0.0), "E", true)
	rules.phase = GameRulesScript.Phase.TURN_CLOWN
	ai._choose_state()
	assert_eq(ai.state, BotAIScript.State.FLEE, "flee on opponent turn")
	ai._choose_target()
	# Flee target should be opposite of enemy direction.
	assert_true(ai.patrol_target.x < 0.0, "flee target points away")

func test_rescue_state_when_teammate_frozen_nearby() -> void:
	var ctx := _make_setup()
	var rules: Node = ctx["rules"]
	var ai: Node = ctx["ai"]
	rules.register_player("t", "mime", Vector3(3.0, 0.0, 0.0), "T", true)
	rules.players["t"]["frozen"] = true
	rules.phase = GameRulesScript.Phase.TURN_MIME
	ai._choose_state()
	assert_eq(ai.state, BotAIScript.State.RESCUE, "rescue takes priority")

func test_patrol_when_no_targets() -> void:
	var ctx := _make_setup()
	var ai: Node = ctx["ai"]
	ai._choose_state()
	assert_eq(ai.state, BotAIScript.State.PATROL, "patrol with no targets")
