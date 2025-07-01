@tool
extends Node3D

# Tamanho do plano em X,Z
@export var plane_size: Vector2 = Vector2(500, 500)
# Checkbox “botão” pra regenerar no editor
@export var regenerate: bool = false

var _body: StaticBody3D
var _mesh: MeshInstance3D
var _col: CollisionShape3D

func _ready() -> void:
	if Engine.is_editor_hint():
		# Habilita _process em modo tool e já desenha uma vez
		set_process(true)
		_build()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and regenerate:
		regenerate = false
		_build()

func _build() -> void:
	# 0) Remove qualquer geração anterior
	for child in get_children():
		child.queue_free()
	_body = null
	_mesh = null
	_col  = null

	# 1) StaticBody3D
	_body = StaticBody3D.new()
	add_child(_body)
	_body.owner = get_owner()

	# 2) MeshInstance3D + PlaneMesh
	_mesh = MeshInstance3D.new()
	_body.add_child(_mesh)
	_mesh.owner = get_owner()
	var plane = PlaneMesh.new()
	plane.size = plane_size
	_mesh.mesh = plane

	# 3) CollisionShape3D idêntico ao mesh
	_col = CollisionShape3D.new()
	_body.add_child(_col)
	_col.owner = get_owner()
	_col.shape = plane.create_trimesh_shape()
