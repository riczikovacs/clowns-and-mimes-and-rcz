extends Control

## Pre-match lobby. Shows code if hosting, players joining, and matchmaking status.
## Transitions to the arena scene once matchmaking is complete.

signal requested_screen(screen: String)

@onready var status_label: Label = $Center/Status
@onready var code_label: Label = $Center/Code
@onready var players_box: VBoxContainer = $Center/Players
@onready var back_button: Button = $BackButton

func _ready() -> void:
	back_button.pressed.connect(func(): requested_screen.emit("menu"))
	_render()
	_simulate_matchmaking()

func _render() -> void:
	match GameState.mode:
		GameState.Mode.HOST:
			status_label.text = "Hosting on " + GameState.topology_as_string() + ". Waiting for friends to join."
			code_label.text = "Code: %s" % _get_code_or_placeholder()
		GameState.Mode.JOIN:
			status_label.text = "Joining lobby."
			code_label.text = "Code: %s" % GameState.lobby_code
		GameState.Mode.OPEN:
			status_label.text = "Searching for an open lobby."
			code_label.text = ""
		_:
			status_label.text = "Offline mode."
			code_label.text = ""

func _get_code_or_placeholder() -> String:
	if not GameState.lobby_code.is_empty():
		return GameState.lobby_code
	GameState.lobby_code = _placeholder_code()
	return GameState.lobby_code

static func _placeholder_code() -> String:
	var alphabet := "BCDFGHJKLMNPQRSTVWXYZ23456789"
	var out := ""
	for _i in range(6):
		out += alphabet[randi() % alphabet.length()]
	return out

func _simulate_matchmaking() -> void:
	for p in [GameState.username, "Bot Mime", "Bot Clown"]:
		var l := Label.new()
		l.text = "- " + p
		players_box.add_child(l)
	await get_tree().create_timer(1.5).timeout
	status_label.text = "Matchmaking complete. Transitioning to the arena..."
	await get_tree().create_timer(0.8).timeout
	requested_screen.emit("arena")
