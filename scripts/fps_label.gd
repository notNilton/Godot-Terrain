extends Label

@export var player_path: NodePath
@onready var player: Node3D = get_node(player_path)

func _process(_delta):
	# 1) FPS
	var fps = Engine.get_frames_per_second()
	# 2) Posição do player
	var pos = player.global_position
	# 3) Monta o texto com FPS + X,Y,Z
	text = "FPS: %d\nX: %.2f\nY: %.2f\nZ: %.2f" % [
		fps,
		pos.x,
		pos.y,
		pos.z
	]
