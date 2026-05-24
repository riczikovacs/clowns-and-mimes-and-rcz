extends CharacterBody3D

## Local player controller. WASD move, mouse look, hold Shift to sprint.

signal sprint_changed(value: float)
signal frozen_changed(frozen: bool)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
const MAX_SPRINT := 100.0
const SPRINT_DRAIN_PER_S := 25.0
const SPRINT_REGEN_PER_S := 15.0
const LOOK_SENSITIVITY := 0.0025

@export var team: String = "mime"
@export var bot: bool = false

var sprint_energy: float = MAX_SPRINT:
	set(value):
		sprint_energy = clampf(value, 0.0, MAX_SPRINT)
		sprint_changed.emit(sprint_energy)

var frozen: bool = false:
	set(value):
		frozen = value
		frozen_changed.emit(frozen)

@onready var camera: Camera3D = $Camera

func _ready() -> void:
	if not bot:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if bot:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		camera.rotate_x(-event.relative.y * LOOK_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -1.2, 1.2)
	elif event.is_action_pressed("ui_pause"):
		var mode := Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(mode)

func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var input_dir := Vector3.ZERO
	input_dir.z -= Input.get_action_strength("move_forward")
	input_dir.z += Input.get_action_strength("move_back")
	input_dir.x -= Input.get_action_strength("move_left")
	input_dir.x += Input.get_action_strength("move_right")
	input_dir = input_dir.normalized()
	var sprinting := Input.is_action_pressed("sprint") and sprint_energy > 0.0 and input_dir.length() > 0.0
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var basis_dir := transform.basis * input_dir
	velocity.x = basis_dir.x * speed
	velocity.z = basis_dir.z * speed
	move_and_slide()
	if sprinting:
		sprint_energy -= SPRINT_DRAIN_PER_S * delta
	else:
		sprint_energy += SPRINT_REGEN_PER_S * delta
