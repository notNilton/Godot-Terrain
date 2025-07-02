extends CharacterBody3D

# — tuning —
const SPEED         : float = 5.0
const JUMP_VELOCITY : float = 4.5
const MOUSE_SENS    : float = 0.003
const MAX_PITCH     : float = deg_to_rad(80)
const MIN_PITCH     : float = deg_to_rad(-80)

# — carving params —
@export var carve_radius : float = 2.0
@export var carve_depth  : float = 1.0

# runtime vars
var camera  : Camera3D
var pitch   : float = 0.0
var fly_mode: bool  = false

func _ready():
	camera = $FirstPersonCamera
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pitch = camera.rotation.x

func _input(event):
	# mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clamp(pitch - event.relative.y * MOUSE_SENS, MIN_PITCH, MAX_PITCH)
		camera.rotation.x = pitch

	# toggle fly/gravity
	if Input.is_action_just_pressed("toggle_fly"):
		fly_mode = not fly_mode
		print("→ Fly mode ON" if fly_mode else "→ Gravity mode ON")

	# carve hole when "click" action is pressed
	if Input.is_action_just_pressed("click"):
		_attempt_carve()

func _physics_process(delta: float) -> void:
	# WASD movement
	var h = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var v = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")

	var b = global_transform.basis
	var forward_dir = -b.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	var right_dir = b.x
	right_dir.y = 0
	right_dir = right_dir.normalized()

	var dir = (right_dir * h + forward_dir * v)
	if dir.length() > 1:
		dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	if fly_mode:
		velocity.y = 0
	else:
		if is_on_floor():
			velocity.y = -0.1
			if Input.is_action_just_pressed("move_jump"):
				velocity.y = JUMP_VELOCITY
		else:
			velocity.y += get_gravity().y * delta

	move_and_slide()

func _attempt_carve() -> void:
	var from = camera.global_transform.origin
	var to   = from + -camera.global_transform.basis.z * 5.0

	var params = PhysicsRayQueryParameters3D.new()
	params.from    = from
	params.to      = to
	params.exclude = [self]

	var space  = get_world_3d().direct_space_state
	var result = space.intersect_ray(params)
	if result.size() == 0:
		return

	var collider     = result["collider"]
	var terrain_node = collider.get_parent()
	if terrain_node and terrain_node.has_method("carve_hole"):
		terrain_node.carve_hole(result["position"], carve_radius, carve_depth)
