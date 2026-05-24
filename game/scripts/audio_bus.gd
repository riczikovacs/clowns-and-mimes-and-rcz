extends Node

## Provides three logical buses: Music, SFX, UI. Bus configuration is bootstrapped
## here so the project boots without a pre-built default_bus_layout.tres.

const BUSES := ["Music", "SFX", "UI"]

func _ready() -> void:
	_ensure_buses()

func _ensure_buses() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")
			AudioServer.set_bus_volume_db(idx, 0.0)

func set_bus_volume(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)

func mute_bus(bus_name: String, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)
