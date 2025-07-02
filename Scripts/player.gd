extends CharacterBody3D

# — tuning —
const SPEED         = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENS    = 0.003
const MAX_PITCH     = deg_to_rad(80)
const MIN_PITCH     = deg_to_rad(-80)

@onready var camera = $FirstPersonCamera
var pitch = 0.0

# controla se estamos voando (sem gravidade) ou não
var fly_mode = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pitch = camera.rotation.x

func _input(event):
	# olhar com o mouse
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		pitch = clamp(pitch - event.relative.y * MOUSE_SENS, MIN_PITCH, MAX_PITCH)
		camera.rotation.x = pitch

	# alterna fly/gravity via ação "toggle_fly" (configure no InputMap)
	if Input.is_action_just_pressed("toggle_fly"):
		fly_mode = not fly_mode
		if fly_mode:
			print("→ Fly mode ON")
		else:
			print("→ Gravity mode ON")

func _physics_process(delta):
	# 1) entrada WASD
	var h = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var v = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")

	# 2) base XZ no espaço mundial
	var world_basis = global_transform.basis
	var forward_dir = -world_basis.z
	var right_dir   =  world_basis.x
	forward_dir.y = 0; forward_dir = forward_dir.normalized()
	right_dir.y   = 0; right_dir   = right_dir.normalized()

	# 3) vetor de movimento horizontal
	var dir = (right_dir * h + forward_dir * v)
	if dir.length() > 1:
		dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	if fly_mode:
		# MODO FLY: zera a velocidade no eixo Y (mantém altura)
		velocity.y = 0
	else:
		# MODO GRAVIDADE: comportamento padrão
		if is_on_floor():
			velocity.y = -0.1   # pequeno “grude” no chão
			if Input.is_action_just_pressed("move_jump"):
				velocity.y = JUMP_VELOCITY
		else:
			# aplica só componente Y da gravidade
			velocity.y += get_gravity().y * delta

	move_and_slide()
