extends DirectionalLight3D

# Duração do “dia” em segundos (uma volta completa)
@export var day_length: float = 60.0

# Velocidade de rotação em rad/s, calculada em _ready()
var _rotation_speed: float = 0.0

func _ready() -> void:
	# 2π radianos em day_length segundos
	_rotation_speed = TAU / day_length

func _process(delta: float) -> void:
	# Rotaciona o sol ao redor do eixo X local
	# (ajuste para outro eixo se preferir)
	rotate_x(_rotation_speed * delta)
