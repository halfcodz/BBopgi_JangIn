class_name BridgeMachine
extends ClawMachine
## 일본식 프라이즈 피규어 기계(다리 세팅, 橋渡し).
## 두 개의 봉(다리) 위에 피규어 상자가 걸쳐 있고, 2발 집게로 상자를 밀고·들어 올려
## 봉 사이로 떨어뜨리면 획득. 봉 아래는 전부 배출구로 이어진 구덩이다.

var bar_y := 0.96
var bars_root: Node3D


func _setup_dims() -> void:
	W = 1.0
	D = 0.95
	base_h = 0.8
	glass_top = 1.86
	header_h = 0.3
	ix = 0.45
	z_back = -0.42
	z_front = 0.40
	chute_x = 0.2   # 앞쪽 배출구 구멍 오른쪽 끝
	chute_z = 0.0
	claw_size = 1.05
	rest_y = glass_top - 0.34
	bin_y = 0.12
	open_h = 0.36
	rail_y = glass_top - 0.05
	bar_y = base_h + 0.16


func _home() -> Vector3:
	return Vector3(ix - 0.12, 0, z_front - 0.12)


func _gap() -> float:
	return float(settings.get("bridge_gap", 0.17))


func _win_y() -> float:
	return bar_y - 0.12


func _build_bed() -> void:
	var inner := _mat(Color(0.16, 0.12, 0.2), 0.8)
	var felt := StandardMaterial3D.new()
	felt.albedo_texture = load("res://assets/textures/machine/prize_bed.png")
	felt.uv1_scale = Vector3(3, 3, 3)
	felt.roughness = 0.95
	# 구덩이 바닥: 뒤쪽이 높고 앞쪽(배출구)으로 미끄러지는 경사판
	var drop := (base_h - 0.04) - (bin_y + 0.03)
	var depth := z_front - z_back
	var ang := atan2(drop, depth)
	var len := sqrt(drop * drop + depth * depth)
	var slope := _box(Vector3(ix * 2.0, 0.03, len + 0.05), Vector3(0, (base_h - 0.04 + bin_y + 0.03) * 0.5, (z_back + z_front) * 0.5), felt, false, null, Vector3(ang, 0, 0))
	var sb := StaticBody3D.new()
	sb.collision_layer = LAYER_ENV
	var slick := PhysicsMaterial.new()
	slick.friction = 0.12
	sb.physics_material_override = slick
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(ix * 2.0, 0.03, len + 0.05)
	cs.shape = bs
	sb.add_child(cs)
	sb.transform = slope.transform
	add_child(sb)
	# 오른쪽 앞(배출구 옆)은 막혀 있으므로 왼쪽으로 흘러가게 하는 경사 칸막이
	_box(Vector3(0.02, 0.32, 0.3), Vector3(chute_x + 0.01, bin_y + 0.16, z_front - 0.12), inner, true, null, Vector3(0, -0.5, 0))
	_rebuild_bars()


func _rebuild_bars() -> void:
	if bars_root:
		bars_root.queue_free()
	bars_root = Node3D.new()
	bars_root.name = "Bars"
	add_child(bars_root)
	var chrome := _mat(Color(0.88, 0.88, 0.9), 0.15, 1.0)
	var rubber := _mat(Color(0.1, 0.1, 0.12), 0.7)
	var post := _mat(Color(0.75, 0.75, 0.78), 0.3, 0.7)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.55
	var r := 0.013
	var length := z_front - z_back - 0.08
	for sx in [-1.0, 1.0]:
		var x: float = sx * _gap() * 0.5
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = length
		cm.radial_segments = 20
		mi.mesh = cm
		mi.material_override = chrome
		mi.rotation.x = PI / 2
		mi.position = Vector3(x, bar_y - r, (z_back + z_front) * 0.5)
		bars_root.add_child(mi)
		# 가운데 고무 튜브(미끄럼 방지)
		var rb := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = r + 0.002
		rm.bottom_radius = r + 0.002
		rm.height = length * 0.6
		rm.radial_segments = 20
		rb.mesh = rm
		rb.material_override = rubber
		rb.rotation.x = PI / 2
		rb.position = mi.position
		bars_root.add_child(rb)
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER_ENV
		sb.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = r + 0.002
		cy.height = length
		cs.shape = cy
		sb.add_child(cs)
		sb.rotation.x = PI / 2
		sb.position = mi.position
		bars_root.add_child(sb)
		# 받침 기둥(앞/뒤)
		for zz in [z_back + 0.05, z_front - 0.05]:
			var h: float = bar_y - (base_h - 0.25)
			_box(Vector3(0.03, h, 0.03), Vector3(x, base_h - 0.25 + h * 0.5 - r, zz), post, false, bars_root)
	# 봉 끝 고정 블록(상자가 앞뒤로 빠지지 않도록 약간의 턱)
	for zz in [z_back + 0.03, z_front - 0.03]:
		_box(Vector3(_gap() + 0.08, 0.02, 0.02), Vector3(0, bar_y - 0.03, zz), post, false, bars_root)


func _build_chute() -> void:
	var inner := _mat(Color(0.14, 0.12, 0.18), 0.85)
	var cw := chute_x - (-ix)
	# 배출구 위쪽 앞면 안쪽 벽
	var open_y1 := bin_y + open_h
	_wall(Vector3(cw, base_h - open_y1, 0.02), Vector3((-ix + chute_x) * 0.5, (open_y1 + base_h) * 0.5, z_front + 0.03))
	_wall(Vector3(ix - chute_x, base_h - bin_y, 0.02), Vector3((chute_x + ix) * 0.5, (bin_y + base_h) * 0.5, z_front + 0.03))
	# 배출구 받침과 앞턱
	_box(Vector3(cw, 0.02, 0.18), Vector3((-ix + chute_x) * 0.5, bin_y - 0.01, z_front + 0.04), inner, true, null, Vector3(deg_to_rad(6), 0, 0))
	_wall(Vector3(cw, 0.04, 0.02), Vector3((-ix + chute_x) * 0.5, bin_y + 0.02, D * 0.5 + 0.02))
	# 배출 감지: 봉 아래 전체
	bin_area = Area3D.new()
	bin_area.collision_layer = 0
	bin_area.collision_mask = LAYER_PRIZE
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var h := _win_y() - bin_y + 0.05
	bs.size = Vector3(ix * 2.0, h, z_front - z_back + 0.2)
	cs.shape = bs
	cs.position = Vector3(0, bin_y - 0.05 + h * 0.5, (z_back + z_front) * 0.5 + 0.08)
	bin_area.add_child(cs)
	add_child(bin_area)
	bin_area.body_entered.connect(_on_bin_body)
	var bl := OmniLight3D.new()
	bl.position = Vector3(0, base_h + 0.05, 0)
	bl.omni_range = 0.8
	bl.light_energy = 0.5
	add_child(bl)
	# 안내 스티커
	var tip := Label3D.new()
	tip.text = "봉 사이로 떨어뜨리면 GET!"
	tip.font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	tip.font_size = 40
	tip.pixel_size = 0.0011
	tip.outline_size = 10
	tip.modulate = Color(1, 0.95, 0.4)
	tip.outline_modulate = Color(0.5, 0.05, 0.1)
	tip.position = Vector3(-0.15, glass_top - 0.1, D * 0.5 - 0.012)
	add_child(tip)


func _prong_on_floor() -> bool:
	for tip in claw.tip_positions():
		if to_local(tip).y <= bar_y - 0.06:
			return true
	return false


func fill_random(count: int, ids: Array = []) -> void:
	if ids.is_empty():
		ids = settings.get("prize_ids", ["jp_figure_a"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	count = clampi(count, 1, 2)
	for i in count:
		var id: String = ids[rng.randi() % ids.size()]
		var z := 0.0 if count == 1 else (-0.12 + i * 0.24)
		_place_on_bars(id, z, rng)


func _place_on_bars(id: String, z: float, rng: RandomNumberGenerator) -> Prize:
	var lp := Vector3(rng.randf_range(-0.02, 0.02), bar_y + 0.004, z)
	var p := add_prize(id, to_global(lp), PI if rng.randf() < 0.5 else 0.0, null)
	return p


func _return_to_bed(p: Prize) -> void:
	if not is_instance_valid(p):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	p.teleport_to(to_global(Vector3(0, bar_y + 0.12, 0.0)), 0.0)
	for b in p.bodies:
		b.global_transform = Transform3D(global_transform.basis, b.global_position)


func _on_settings_changed(id: String) -> void:
	super._on_settings_changed(id)
	if id == machine_id and state == State.IDLE and bars_root:
		var cur: float = abs(bars_root.get_child(0).position.x) * 2.0 if bars_root.get_child_count() > 0 else 0.0
		if abs(cur - _gap()) > 0.002:
			_rebuild_bars()
