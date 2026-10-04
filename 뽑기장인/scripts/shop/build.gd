class_name Build
extends RefCounted
## 가게 소품을 만들 때 쓰는 공용 도우미

static func mat(color: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func glass(tint := Color(0.85, 0.92, 1.0, 0.08)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	m.roughness = 0.02
	m.metallic_specular = 1.0
	m.metallic = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, collide_layer := 0, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	if collide_layer != 0:
		var sb := StaticBody3D.new()
		sb.collision_layer = collide_layer
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		parent.add_child(sb)
	return mi


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r2 < 0 else r2
	cm.height = h
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func text(parent: Node3D, t: String, pos: Vector3, size := 48, px := 0.0012, color := Color.WHITE, outline := Color(0.3, 0.1, 0.25), font := "res://assets/fonts/Jua-Regular.ttf") -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = load(font)
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = max(4, size / 6)
	l.position = pos
	parent.add_child(l)
	return l


## 플레이어 시선(E)으로 상호작용할 몸체
static func interact_body(parent: Node3D, owner_obj: Object, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 16
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.set_meta("interactable", owner_obj)
	parent.add_child(sb)
	return sb


## 플레이어가 통과하지 못하게 막는 몸체(상품과는 부딪히지 않음)
static func blocker(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 8
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)


static func decor(parent: Node3D, name: String, pos: Vector3, scale := 1.0, rot_y := 0.0) -> Node3D:
	var ps: PackedScene = load("res://assets/decor/%s.glb" % name)
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation.y = rot_y
	parent.add_child(n)
	return n
