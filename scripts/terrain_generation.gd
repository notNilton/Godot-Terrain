@tool
extends Node3D

# — Mesh Settings —
@export_group("Mesh Settings")
@export var plane_size     : Vector2 = Vector2(500, 500)
@export_range(2, 512, 1) var res_x : int = 100
@export_range(2, 512, 1) var res_z : int = 100

# — Build & Seed —
@export_group("Build Settings")
@export var regenerate     : bool = false
@export_group("Noise Settings")
@export_range(0, 10000, 1) var noise_seed : int = 0

# — Zone Boundaries —
@export_group("Zones")
@export_range(0.0, 1.0, 0.01) var sea_level      : float = 0.2
@export_range(0.0, 1.0, 0.01) var mountain_level : float = 0.6

# — Sea Settings —
@export_group("Sea Settings")
@export_range(0.0, 50.0, 0.1)  var sea_amplitude    : float = 5.0
@export_range(0.1, 200.0, 1.0) var sea_scale        : float = 100.0
@export_range(1, 8, 1)         var sea_octaves      : int   = 2
@export_range(0.0, 1.0, 0.01)  var sea_gain         : float = 0.5
@export_range(0.1, 4.0, 0.1)   var sea_lacunarity   : float = 2.0

# — Plain Settings —
@export_group("Plain Settings")
@export_range(0.0, 50.0, 0.1)  var plain_amplitude  : float = 10.0
@export_range(0.1, 200.0, 1.0) var plain_scale      : float = 50.0
@export_range(1, 8, 1)         var plain_octaves    : int   = 4
@export_range(0.0, 1.0, 0.01)  var plain_gain       : float = 0.5
@export_range(0.1, 4.0, 0.1)   var plain_lacunarity : float = 2.0

# — Mountain Settings —
@export_group("Mountain Settings")
@export_range(0.0, 100.0, 0.1) var mountain_amplitude   : float = 20.0
@export_range(0.1, 200.0, 1.0) var mountain_scale       : float = 25.0
@export_range(1, 12, 1)        var mountain_octaves     : int   = 6
@export_range(0.0, 1.0, 0.01)  var mountain_gain        : float = 0.4
@export_range(0.1, 4.0, 0.1)   var mountain_lacunarity  : float = 2.5

# — Color Settings —
@export_group("Color Settings")
@export var sea_color      : Color = Color(0.4, 0.6, 0.8)
@export var ground_color   : Color = Color(0.7, 0.8, 0.6)
@export var mountain_color : Color = Color(0.9, 0.9, 0.9)

# Runtime data
var terrain_mesh   : ArrayMesh
var verts          : PackedVector3Array
var normals        : PackedVector3Array
var colors         : PackedColorArray
var indices        : PackedInt32Array
var mi             : MeshInstance3D
var col_shape      : CollisionShape3D

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
	# limpa filhos
	for child in get_children():
		child.queue_free()

	# StaticBody3D pai
	var body = StaticBody3D.new()
	add_child(body)
	body.owner = get_owner()

	# inicializa arrays
	verts   = PackedVector3Array()
	normals = PackedVector3Array()
	colors  = PackedColorArray()
	indices = PackedInt32Array()

	# preenche vértices, normais, cores
	var half_x = plane_size.x * 0.5
	var half_z = plane_size.y * 0.5
	for x in range(res_x + 1):
		for z in range(res_z + 1):
			var u = float(x) / res_x
			var v = float(z) / res_z
			var wx = u * plane_size.x - half_x
			var wz = v * plane_size.y - half_z
			var h  = _height_fbm(wx, wz)

			verts.append(Vector3(wx, h, wz))
			normals.append(Vector3.UP)

			# cor por zona
			var max_amp = max(sea_amplitude, plain_amplitude, mountain_amplitude)
			var hn = clamp(h / max_amp, 0.0, 1.0)
			var col: Color
			if hn < sea_level:
				col = sea_color
			elif hn < mountain_level:
				var t = (hn - sea_level) / (mountain_level - sea_level)
				col = ground_color.lerp(mountain_color, t)
			else:
				col = mountain_color
			colors.append(col)

	# preenche índices
	for x in range(res_x):
		for z in range(res_z):
			var i0 = x * (res_z + 1) + z
			var i1 = i0 + (res_z + 1)
			var i2 = i1 + 1
			var i3 = i0 + 1
			indices.append_array([i0, i1, i2,   i0, i2, i3])

	# cria e popula o ArrayMesh
	terrain_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# adiciona MeshInstance3D
	mi = MeshInstance3D.new()
	mi.mesh = terrain_mesh
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	body.add_child(mi)
	mi.owner = get_owner()

	# adiciona colisão
	col_shape = CollisionShape3D.new()
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(col_shape)
	col_shape.owner = get_owner()

func carve_hole(world_pos: Vector3, radius: float, depth: float) -> void:
	# 1) convert world → local
	var local = to_local(world_pos)
	# 2) modify just the vertex positions within the carve radius
	for i in verts.size():
		var v = verts[i]
		var d = Vector2(v.x, v.z).distance_to(Vector2(local.x, local.z))
		if d < radius:
			var t = 1.0 - (d / radius)
			v.y -= depth * t
			verts[i] = v
	# 3) rebuild the ArrayMesh surface
	terrain_mesh.clear_surfaces()  # ← removes all existing surfaces :contentReference[oaicite:0]{index=0}
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# 4) update the collision shape to match the new mesh
	col_shape.shape = terrain_mesh.create_trimesh_shape()

func _height_fbm(wx: float, wz: float) -> float:
	var nx = wx / plain_scale
	var nz = wz / plain_scale
	var base = _noise2d(nx, nz) * 0.5 + 0.5
	if base < sea_level:
		return _fbm(wx, wz, sea_octaves, sea_scale, sea_gain, sea_lacunarity) * sea_amplitude
	elif base < mountain_level:
		return _fbm(wx, wz, plain_octaves, plain_scale, plain_gain, plain_lacunarity) * plain_amplitude
	else:
		return abs(_fbm(wx, wz, mountain_octaves, mountain_scale, mountain_gain, mountain_lacunarity)) * mountain_amplitude

func _fbm(wx: float, wz: float, octs: int, scale: float, gain: float, lac: float) -> float:
	var sum = 0.0
	var amp = 1.0
	var freq = 1.0
	for i in range(octs):
		sum += amp * _noise2d((wx / scale) * freq, (wz / scale) * freq)
		amp *= gain
		freq *= lac
	return sum

func _noise2d(x: float, y: float) -> float:
	var xi = int(floor(x))
	var yi = int(floor(y))
	var xf = x - xi
	var yf = y - yi
	var v00 = _hash(xi, yi)
	var v10 = _hash(xi+1, yi)
	var v01 = _hash(xi, yi+1)
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
