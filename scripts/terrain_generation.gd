@tool
extends Node3D

# — parâmetros do Inspector —
@export_group("Mesh Settings")
@export var plane_size : Vector2       = Vector2(500, 500)
@export_range(2, 512, 1)  var res_x       : int       = 100
@export_range(2, 512, 1)  var res_z       : int       = 100

@export_group("Color Settings")
@export var sea_level       : float = 0.2   # abaixo disto é “mar”
@export var mountain_level  : float = 0.6   # acima disto é “montanha”
@export var sea_color       : Color = Color(0.4, 0.6, 0.8)
@export var ground_color    : Color = Color(0.7, 0.8, 0.6)
@export var mountain_color  : Color = Color(0.9, 0.9, 0.9)

@export_group("Height Settings")
@export_range(0.0, 100.0, 0.1) var height_amplitude : float = 10.0
@export var regenerate                  : bool      = false

@export_group("Noise Settings")
@export_range(0, 10000, 1)   var noise_seed      : int   = 0
@export_range(1, 16, 1)      var noise_octaves   : int   = 4

@export_group("Noise fBM Settings")
@export_range(0.1, 4.0, 0.1)  var noise_lacunarity : float = 2.0
@export_range(0.0, 1.0, 0.01) var noise_gain       : float = 0.5
@export_range(1.0, 200.0, 1.0) var noise_scale     : float = 50.0   # “zoom” do noise

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_build_terrain()
	else:
		_build_terrain()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and regenerate:
		regenerate = false
		_build_terrain()

func _build_terrain() -> void:
	# 1) limpa geração anterior
	for c in get_children():
		c.queue_free()

	# 2) StaticBody3D pai
	var body = StaticBody3D.new()
	add_child(body)
	body.owner = get_owner()

	# 3) gera mesh + instancia MeshInstance3D
	var terrain_mesh = _create_terrain_mesh()
	var mi = MeshInstance3D.new()
	mi.mesh = terrain_mesh
	body.add_child(mi)
	mi.owner = get_owner()
	
	# depois de mi.mesh = terrain_mesh
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat

	# 4) cria CollisionShape3D
	var col = CollisionShape3D.new()
	col.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(col)
	col.owner = get_owner()

func _create_terrain_mesh() -> ArrayMesh:
	var m = ArrayMesh.new()
	var verts   = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors  = PackedColorArray()
	var idx     = PackedInt32Array()

	var half_x = plane_size.x * 0.5
	var half_z = plane_size.y * 0.5

	# gera vértices + normais básicas
	for x in range(res_x + 1):
			for z in range(res_z + 1):
				var u = float(x) / res_x
				var v = float(z) / res_z
				var wx = u * plane_size.x - half_x
				var wz = v * plane_size.y - half_z
				var h  = _height_fbm(wx, wz)
				verts.append(Vector3(wx, h, wz))
				normals.append(Vector3.UP)

				# — normaliza h para [0,1] e decide cor —
				var hn = clamp(h / height_amplitude, 0.0, 1.0)
				var col: Color
				if hn < sea_level:
					col = sea_color
				elif hn < mountain_level:
					# blend entre ground e mountain
					var t = (hn - sea_level) / (mountain_level - sea_level)
					col = ground_color.lerp(mountain_color, t)
				else:
					col = mountain_color
				colors.append(col)

	# índices de triângulos (2 por quad)
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
	arrays[Mesh.ARRAY_COLOR]  = colors     # ← aqui
	arrays[Mesh.ARRAY_INDEX]  = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


	return m

func _height_fbm(wx: float, wz: float) -> float:
	var nx = wx / noise_scale
	var nz = wz / noise_scale
	var amplitude = 1.0
	var frequency = 1.0
	var sum = 0.0
	for i in range(noise_octaves):
		sum += amplitude * _noise2d(nx * frequency, nz * frequency)
		frequency *= noise_lacunarity
		amplitude *= noise_gain
	return sum * height_amplitude

func _noise2d(x: float, y: float) -> float:
	var xi = int(floor(x))
	var yi = int(floor(y))
	var xf = x - xi
	var yf = y - yi

	var v00 = _hash(xi,   yi)
	var v10 = _hash(xi+1, yi)
	var v01 = _hash(xi,   yi+1)
	var v11 = _hash(xi+1, yi+1)

	var u = _fade(xf)
	var v = _fade(yf)

	var i1 = lerp(v00, v10, u)
	var i2 = lerp(v01, v11, u)
	return lerp(i1, i2, v) * 2.0 - 1.0

func _fade(t: float) -> float:
	return t * t * t * (t * (t * 6 - 15) + 10)

func _hash(x: int, y: int) -> float:
	var h = x * 374761393 + y * 668265263 + noise_seed * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0x7fffffff) / 1073741824.0
