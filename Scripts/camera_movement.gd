extends Camera3D

@export var mouse_sensitivity: float = 0.2
@export var invert_y: bool = false

func _ready() -> void:
	# Captura o mouse ao iniciar
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var delta: Vector2 = event.relative

		# yaw em graus diretamente
		rotation_degrees.y -= delta.x * mouse_sensitivity

		# pitch em graus com clamp
		var pitch_delta = (delta.y if invert_y else -delta.y) * mouse_sensitivity
		rotation_degrees.x = clamp(rotation_degrees.x + pitch_delta, -90.0, 90.0)
