class_name PrizeFactory
extends RefCounted
## 에셋(glb 메시 + json 래그돌 정의)으로 실제 물리 상품을 만든다.

const PLUSH_SHADER := preload("res://assets/shaders/plush.gdshader")
const GOODS_SHADER := preload("res://assets/shaders/goods.gdshader")
const LAYER_ENV := 1
const LAYER_PRIZE := 2
const LAYER_CLAW := 4

static var _meta_cache := {}
static var _scene_cache := {}
static var _mat_cache := {}
static var _tex_cache := {}


static func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


static func load_meta(model: String) -> Dictionary:
	if not _meta_cache.has(model):
		var f := FileAccess.open("res://assets/prizes/%s.json" % model, FileAccess.READ)
		if f == null:
			push_error("상품 정의를 찾을 수 없음: " + model)
			return {}
		_meta_cache[model] = JSON.parse_string(f.get_as_text())
	return _meta_cache[model]


static func load_scene(model: String) -> PackedScene:
	if not _scene_cache.has(model):
		_scene_cache[model] = load("res://assets/prizes/%s.glb" % model)
	return _scene_cache[model]


static func fabric_material(fabric: String, colors: Array) -> Material:
	var key := fabric + str(colors)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = PLUSH_SHADER
	m.set_shader_parameter("main_color", colors[0])
	m.set_shader_parameter("accent_color", colors[1] if colors.size() > 1 else colors[0])
	m.set_shader_parameter("accent2_color", colors[2] if colors.size() > 2 else Color(0.98, 0.72, 0.78))
	var base := "res://assets/textures/fabric/"
	match fabric:
		"velboa":
			m.set_shader_parameter("fabric_albedo", _tex(base + "velboa_albedo.png"))
			m.set_shader_parameter("fabric_normal", _tex(base + "velboa_normal.png"))
			m.set_shader_parameter("tile_size", 0.05)
			m.set_shader_parameter("sheen", 0.7)
			m.set_shader_parameter("normal_strength", 1.1)
		_:
			m.set_shader_parameter("fabric_albedo", _tex(base + "minky_albedo.png"))
			m.set_shader_parameter("fabric_normal", _tex(base + "minky_normal.png"))
			m.set_shader_parameter("tile_size", 0.035)
	_mat_cache[key] = m
	return m


static func accessory_material(kind: String) -> Material:
	if _mat_cache.has("acc_" + kind):
		return _mat_cache["acc_" + kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	match kind:
		"eye":
			m.roughness = 0.06
			m.metallic_specular = 0.9
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.02
		"thread":
			m.roughness = 0.65
			m.albedo_texture = _tex("res://assets/textures/fabric/thread_albedo.png")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = false
			m.uv1_scale = Vector3(220, 220, 220)
		"plastic":
			m.roughness = 0.25
			m.metallic_specular = 0.6
		"metal":
			m.metallic = 1.0
			m.roughness = 0.22
		"clear":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1, 1, 1, 0.35)
			m.roughness = 0.04
			m.metallic_specular = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"cardboard":
			m.roughness = 0.75
		"foil":
			m.metallic = 0.65
			m.roughness = 0.28
		_:
			m.roughness = 0.6
	_mat_cache["acc_" + kind] = m
	return m


## 솜 인형은 겉 털과 솜이 눌리므로, 충돌 형상을 보이는 것보다 살짝 작게 잡아
## 집게 발이 원단 속으로 파고드는 느낌을 낸다.
static var squish := 0.88


static func _make_shape(sd: Dictionary, s: float, soft: bool = true) -> Array:
	var rs := s * (squish if soft else 1.0)
	## 반환: [Shape3D, Transform3D(바디 로컬)]
	match sd["type"]:
		"sphere":
			var sp := SphereShape3D.new()
			sp.radius = sd["radius"] * rs
			return [sp, Transform3D(Basis(), _v(sd["center"]) * s)]
		"capsule":
			var a := _v(sd["a"]) * s
			var b := _v(sd["b"]) * s
			var r: float = sd["radius"] * rs
			var cap := CapsuleShape3D.new()
			cap.radius = r
			cap.height = a.distance_to(b) + 2.0 * r + 0.0001
			var dir := (b - a).normalized()
			var basis := Basis()
			if dir.cross(Vector3.UP).length() > 0.001:
				basis = Basis(Quaternion(Vector3.UP, dir))
			elif dir.y < 0:
				basis = Basis(Vector3.RIGHT, PI)
			return [cap, Transform3D(basis, (a + b) * 0.5)]
		"box":
			var bx := BoxShape3D.new()
			bx.size = _v(sd["half"]) * 2.0 * s
			var rot := _v(sd.get("rot", [0, 0, 0]))
			return [bx, Transform3D(Basis.from_euler(rot * PI / 180.0), _v(sd["center"]) * s)]
		"cylinder":
			var cy := CylinderShape3D.new()
			cy.radius = sd["radius"] * rs
			cy.height = sd["height"] * s
			var rot2 := _v(sd.get("rot", [0, 0, 0]))
			return [cy, Transform3D(Basis.from_euler(rot2 * PI / 180.0), _v(sd["center"]) * s)]
		"convex":
			var cv := ConvexPolygonShape3D.new()
			var pts := PackedVector3Array()
			for p in sd["points"]:
				pts.append(_v(p) * rs)
			cv.points = pts
			return [cv, Transform3D()]
	return []


static func _v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## id: PrizeCatalog 의 상품 id. 반환된 Prize 를 트리에 add_child 한 뒤 위치를 잡을 것.
static func create(id: String, rng: RandomNumberGenerator = null, colorway: int = -1) -> Prize:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var item := PrizeCatalog.get_item(id)
	if item.is_empty():
		push_error("알 수 없는 상품: " + id)
		return null
	var model: String = item["model"]
	var meta := load_meta(model)
	var s: float = item.get("scale", 1.0)
	var ways: Array = item["colorways"]
	if colorway < 0 or colorway >= ways.size():
		colorway = rng.randi() % ways.size()
	var colors: Array = ways[colorway]
	var fabric: String = item.get("fabric", meta.get("fabric", "minky"))
	var fab_mat := fabric_material(fabric, colors)

	var prize := Prize.new()
	prize.name = "Prize_" + id
	prize.prize_id = id
	prize.display_name = item["name"]
	prize.cost = item["cost"]
	prize.colorway = colorway

	var pm := PhysicsMaterial.new()
	pm.friction = item.get("friction", 0.9)
	pm.bounce = item.get("bounce", 0.02)
	pm.rough = false

	# 부위 질량 비율 → 상품 총 질량에 맞춘다
	var mass_sum := 0.0
	for p in meta["parts"]:
		mass_sum += float(p["mass"])
	var total_mass: float = item.get("mass", mass_sum)

	var by_name := {}
	for p in meta["parts"]:
		var body := RigidBody3D.new()
		body.name = p["name"]
		body.mass = max(total_mass * float(p["mass"]) / mass_sum, 0.004)
		body.physics_material_override = pm
		body.collision_layer = LAYER_PRIZE
		body.collision_mask = LAYER_ENV | LAYER_PRIZE | LAYER_CLAW
		body.linear_damp = item.get("linear_damp", 0.25)
		body.angular_damp = item.get("angular_damp", 1.2)
		body.can_sleep = true
		body.continuous_cd = true
		body.position = _v(p["origin"]) * s
		for sd in p["shapes"]:
			var res := _make_shape(sd, s, not meta.has("material"))
			if res.is_empty():
				continue
			var cs := CollisionShape3D.new()
			cs.shape = res[0]
			cs.transform = res[1]
			body.add_child(cs)
		prize.add_child(body)
		prize.bodies.append(body)
		by_name[p["name"]] = body
	prize.main_body = prize.bodies[0]

	# 메시 붙이기
	var scene := load_scene(model)
	if scene:
		var inst := scene.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var nm: String = mi.name
			var segs := nm.split("__")
			var part_name := segs[0]
			if not by_name.has(part_name):
				continue
			var body: RigidBody3D = by_name[part_name]
			var mesh_inst := MeshInstance3D.new()
			mesh_inst.mesh = mi.mesh
			mesh_inst.name = nm
			# glb 메시는 인형 좌표계 → 바디(피벗) 기준으로 이동
			mesh_inst.transform = Transform3D(Basis().scaled(Vector3.ONE * s), -body.position)
			if segs.size() >= 3:
				var kind := segs[2]
				if kind == "fabric2":
					mesh_inst.material_override = fabric_material(fabric, [colors[1], colors[1], colors[2] if colors.size() > 2 else colors[1]])
				elif kind == "tint":
					var tc: Color = colors[1] if colors.size() > 1 else colors[0]
					var tkey := "tint_" + tc.to_html()
					if not _mat_cache.has(tkey):
						var tm := StandardMaterial3D.new()
						tm.albedo_color = tc
						tm.roughness = 0.35
						_mat_cache[tkey] = tm
					mesh_inst.material_override = _mat_cache[tkey]
				else:
					mesh_inst.material_override = accessory_material(kind)
			elif meta.has("material"):
				mesh_inst.material_override = _rigid_material(meta["material"], colors, item)
			else:
				mesh_inst.material_override = fab_mat
			body.add_child(mesh_inst)
		inst.free()

	# 관절(래그돌)
	for j in meta.get("joints", []):
		if not (by_name.has(j["a"]) and by_name.has(j["b"])):
			continue
		var ba: RigidBody3D = by_name[j["a"]]
		var bb: RigidBody3D = by_name[j["b"]]
		var jt := Generic6DOFJoint3D.new()
		jt.name = "J_%s_%s" % [j["a"], j["b"]]
		jt.position = _v(j["pivot"]) * s
		if j.has("axis"):
			var ax := _v(j["axis"]).normalized()
			jt.basis = Basis(Quaternion(Vector3.UP, ax)) if ax.cross(Vector3.UP).length() > 0.001 else Basis()
		prize.add_child(jt)
		jt.node_a = jt.get_path_to(ba)
		jt.node_b = jt.get_path_to(bb)
		jt.exclude_nodes_from_collision = true
		var swing := deg_to_rad(float(j["swing"]))
		var twist := deg_to_rad(float(j["twist"]))
		jt.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -swing)
		jt.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, swing)
		jt.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -twist)
		jt.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, twist)
		jt.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -swing)
		jt.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, swing)
		# 솜이 차 있어서 원래 자세로 돌아오려는 힘(스프링)
		var lever: float = max(bb.position.distance_to(jt.position), 0.02 * s) + 0.03 * s
		var k: float = float(j["stiffness"]) * bb.mass * 9.81 * lever / 0.35
		for axis_fn in ["x", "y", "z"]:
			jt.call("set_flag_" + axis_fn, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
			jt.call("set_param_" + axis_fn, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, k)
			jt.call("set_param_" + axis_fn, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_DAMPING, k * float(j["damping"]) * 2.0)
	if item.get("keyring", false):
		_add_keyring(prize, meta, by_name, s, pm)
	return prize


## 키링 고리: 집게 발끝이 걸리기 좋은 금속 고리를 머리 위에 관절로 단다
static func _add_keyring(prize: Prize, meta: Dictionary, by_name: Dictionary, s: float, pm: PhysicsMaterial) -> void:
	var host_name: String = "head" if by_name.has("head") else meta["parts"][0]["name"]
	var host: RigidBody3D = by_name[host_name]
	var host_meta: Dictionary = {}
	for p in meta["parts"]:
		if p["name"] == host_name:
			host_meta = p
	var top := Vector3.ZERO
	var best := -INF
	if meta.has("ring_top"):
		top = _v(meta["ring_top"]) - _v(host_meta["origin"])
		best = top.y
	for sd in host_meta.get("shapes", []):
		if sd["type"] == "sphere":
			var c := _v(sd["center"])
			if c.y + float(sd["radius"]) > best:
				best = c.y + float(sd["radius"])
				top = Vector3(c.x, best, c.z)
	var top_world := host.position + top * s
	var R := 0.013
	var wire := 0.0018
	var ring := RigidBody3D.new()
	ring.name = "keyring"
	ring.mass = 0.006
	ring.physics_material_override = pm
	ring.collision_layer = LAYER_PRIZE
	ring.collision_mask = LAYER_ENV | LAYER_PRIZE | LAYER_CLAW
	ring.angular_damp = 0.6
	ring.position = top_world + Vector3(0, R + 0.007, 0)
	# 원환을 작은 캡슐 8개로 근사
	for k in 8:
		var a0 := TAU * k / 8.0
		var a1 := TAU * (k + 1) / 8.0
		var p0 := Vector3(cos(a0), sin(a0), 0) * R
		var p1 := Vector3(cos(a1), sin(a1), 0) * R
		var cap := CapsuleShape3D.new()
		cap.radius = wire * 1.4
		cap.height = p0.distance_to(p1) + cap.radius * 2.0
		var cs := CollisionShape3D.new()
		cs.shape = cap
		var dir := (p1 - p0).normalized()
		cs.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), (p0 + p1) * 0.5)
		ring.add_child(cs)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = R - wire
	tm.outer_radius = R + wire
	tm.rings = 32
	tm.ring_segments = 10
	mi.mesh = tm
	mi.rotation.x = PI / 2
	mi.material_override = accessory_material("metal")
	ring.add_child(mi)
	# 연결 고리(작은 체인)
	var link := MeshInstance3D.new()
	var lm := TorusMesh.new()
	lm.inner_radius = 0.0028
	lm.outer_radius = 0.0045
	link.mesh = lm
	link.position = Vector3(0, -R - 0.0035, 0)
	link.rotation.z = PI / 2
	link.material_override = accessory_material("metal")
	ring.add_child(link)
	prize.add_child(ring)
	prize.bodies.append(ring)
	var jt := Generic6DOFJoint3D.new()
	jt.name = "J_keyring"
	jt.position = top_world + Vector3(0, 0.002, 0)
	prize.add_child(jt)
	jt.node_a = jt.get_path_to(host)
	jt.node_b = jt.get_path_to(ring)
	for ax in ["x", "y", "z"]:
		jt.call("set_param_" + ax, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -deg_to_rad(80))
		jt.call("set_param_" + ax, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(80))


static func _rigid_material(kind: String, colors: Array, item: Dictionary) -> Material:
	var key := "rigid_%s_%s_%s" % [kind, str(colors), item.get("texture", "")]
	if _mat_cache.has(key):
		return _mat_cache[key]
	if kind.begins_with("goods_"):
		# 말랑이(폼)·키캡(플라스틱)·팝잇(실리콘): 버텍스 컬러 마스크 + 색 조합
		var g := ShaderMaterial.new()
		g.shader = GOODS_SHADER
		g.set_shader_parameter("main_color", colors[0])
		g.set_shader_parameter("accent_color", colors[1] if colors.size() > 1 else colors[0])
		g.set_shader_parameter("accent2_color", colors[2] if colors.size() > 2 else Color(0.2, 0.2, 0.22))
		match kind:
			"goods_soft":
				g.set_shader_parameter("roughness_v", 0.85)
				g.set_shader_parameter("soft", 0.8)
				g.set_shader_parameter("speckle", 0.06)
			"goods_silicone":
				g.set_shader_parameter("roughness_v", 0.42)
				g.set_shader_parameter("soft", 0.3)
			_:
				g.set_shader_parameter("roughness_v", 0.22)
				g.set_shader_parameter("clearcoat_v", 0.8)
		_mat_cache[key] = g
		return g
	var m := StandardMaterial3D.new()
	m.albedo_color = colors[0]
	match kind:
		"capsule":
			m.vertex_color_use_as_albedo = true
			m.albedo_color = colors[0]
			m.roughness = 0.1
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			m.metallic_specular = 0.8
		"printed":
			m.roughness = 0.45
			if item.has("texture"):
				m.albedo_texture = _tex(item["texture"])
				m.albedo_color = Color.WHITE
		"foil":
			m.roughness = 0.3
			m.metallic = 0.5
			if item.has("texture"):
				m.albedo_texture = _tex(item["texture"])
				m.albedo_color = Color.WHITE
		"rubber":
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color.WHITE
			m.roughness = 0.35
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
		_:
			m.roughness = 0.5
	_mat_cache[key] = m
	return m
