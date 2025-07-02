@tool
extends Node3D

# — parâmetros do Inspector —
@export var plane_size: Vector2         = Vector2(500, 500)
@export var height_amplitude: float     = 10.0
@export var regenerate: bool            = false
@export_range(2, 512) var res_x: int    = 100
@export_range(2, 512) var res_z: int    = 100

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_build_terrain()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and regenerate:
		regenerate = false
		_build_terrain()

func _build_terrain() -> void:
	# 1) limpa geração anterior
	for filho in get_children():
		filho.queue_free()

	# 2) Cria um StaticBody3D, pai do mesh e da colisão
	var body = StaticBody3D.new()
	add_child(body)
	body.owner = get_owner()

	# 3) Cria o MeshInstance3D usando o ArrayMesh gerado
	var terrain_mesh: ArrayMesh = _create_terrain_mesh()
	var mi = MeshInstance3D.new()
	mi.mesh = terrain_mesh
	body.add_child(mi)
	mi.owner = get_owner()

	# 4) Cria o CollisionShape3D e o coloca como filho do StaticBody3D
	var col = CollisionShape3D.new()
	col.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(col)
	col.owner = get_owner()

# --- função que gera de fato o ArrayMesh do terreno ---
func _create_terrain_mesh() -> ArrayMesh:
	var mesh = ArrayMesh.new()

	var verts   = PackedVector3Array()
	var normals = PackedVector3Array()
	var idx     = PackedInt32Array()

	var half_x = plane_size.x * 0.5
	var half_z = plane_size.y * 0.5
	var step_x = plane_size.x / float(res_x)
	var step_z = plane_size.y / float(res_z)

	# gera vértices e normais
	for x in range(res_x + 1):
		for z in range(res_z + 1):
			var ux = float(x) / res_x
			var uz = float(z) / res_z
			var world_x = ux * plane_size.x - half_x
			var world_z = uz * plane_size.y - half_z
			var height = _height_func(ux, uz)
			verts.append(Vector3(world_x, height, world_z))
			normals.append(Vector3.UP)  # substitua por cálculo de normal mais preciso depois

	# gera índices de triângulos (2 por quad)
	for x in range(res_x):
		for z in range(res_z):
			var i0 = x * (res_z + 1) + z
			var i1 = i0 + (res_z + 1)
			var i2 = i1 + 1
			var i3 = i0 + 1
			idx.append_array([i0, i1, i2,  i0, i2, i3])

	# monta o ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX]  = idx

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# função de altura “wavelike” — ponto de partida para evoluir depois
func _height_func(u: float, v: float) -> float:
	return sin(u * TAU) * cos(v * TAU) * height_amplitude
