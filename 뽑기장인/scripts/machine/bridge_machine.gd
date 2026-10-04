class_name BridgeMachine
extends ClawMachine
## 일본식 프라이즈 피규어 기계(다리 세팅, 橋渡し).
## 두 개의 봉(다리) 위에 피규어 상자가 걸쳐 있고, 2발 집게로 상자를 밀고·들어 올려
## 봉 사이로 떨어뜨리면 획득. 봉 아래는 전부 배출구로 이어진 구덩이다.

var bar_y := 0.96
var bars_root: Node3D


func _setup_dims() -> void:
	W = 1.0
	D = 1.2
	base_h = 0.8
	glass_top = 1.86
	header_h = 0.3
	ix = 0.45
	z_back = -0.42   # 그 뒤 15cm 는 재고 상자 진열 선반(실제 매장 기계처럼)
	z_front = 0.48
	chute_x = 0.2   # 앞쪽 배출구 구멍 오른쪽 끝
	chute_z = 0.0
	claw_size = 1.0
	claw_style = "ufo"
	rest_y = glass_top - 0.34
	bin_y = 0.12
	open_h = 0.36
	rail_y = glass_top - 0.05
	bar_y = base_h + 0.16


## 일본 기계처럼 집게는 왼쪽 앞(배출구 위) 모서리에서 출발한다
func _home() -> Vector3:
	return Vector3(-ix + 0.18, 0, z_front - 0.14)


# ------------------------------------------------------------------ 외관: 일본 프라이즈 매장의 밝은 흰색 기계
func _cabinet_paint() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.94, 0.95, 0.97)
	m.roughness = 0.2
	m.metallic = 0.1
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	return m


func _header_tex_path() -> String:
	return "res://assets/textures/machine/header_ufo.png"


func _panel_tex_path() -> String:
	return "res://assets/textures/machine/panel_ufo.png"


func _use_bulbs() -> bool:
	return false


func _build_cabinet() -> void:
	super._build_cabinet()
	# 기둥·간판 아래 테마색 LED 줄(사진 속 파란 조명 띠)
	var led := _mat(theme_color, 0.3)
	led.emission_enabled = true
	led.emission = theme_color
	led.emission_energy_multiplier = 2.5
	var hd := D * 0.5
	_box(Vector3(W, 0.012, 0.012), Vector3(0, glass_top + 0.006, hd + 0.006), led)
	_box(Vector3(W, 0.012, 0.012), Vector3(0, base_h - 0.02, hd + 0.006), led)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.008, glass_top - base_h, 0.008), Vector3(sx * (W * 0.5 - 0.005), (glass_top + base_h) * 0.5, hd + 0.004), led)
	# 천장 안쪽 밝은 LED 패널(흰 실내)
	var panel := _mat(Color(1, 1, 1), 0.2)
	panel.emission_enabled = true
	panel.emission = Color(1.0, 0.99, 0.97)
	panel.emission_energy_multiplier = 2.2
	_box(Vector3(ix * 1.9, 0.006, 0.08), Vector3(0, glass_top - 0.008, z_front - 0.06), panel)
	interior_light.light_energy = 3.0


## 뒤쪽: 투명 칸막이 너머 재고 상자 진열 선반 + 상품 큰 포스터
func _build_backdrop(gh: float, white: Material) -> void:
	var hd := D * 0.5
	var shelf_mat := _mat(Color(0.97, 0.97, 0.98), 0.25)
	_box(Vector3(W, gh, 0.02), Vector3(0, base_h + gh * 0.5, -hd + 0.01), white)
	# 투명 칸막이(상자는 앞쪽 구역에서만 움직인다)
	var acr := StandardMaterial3D.new()
	acr.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	acr.albedo_color = Color(0.92, 0.96, 1.0, 0.08)
	acr.roughness = 0.03
	acr.metallic_specular = 0.9
	_box(Vector3(ix * 2.0, gh, 0.006), Vector3(0, base_h + gh * 0.5, z_back - 0.005), acr)
	var ids: Array = settings.get("prize_ids", ["jp_figure_a"])
	var item := PrizeCatalog.get_item(String(ids[0]))
	# 큰 포스터(상자 앞면 그림을 크게)
	if item.has("texture"):
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = load(item["texture"])
		pm.uv1_scale = Vector3(0.6, 0.4, 1)
		pm.roughness = 0.4
		pm.emission_enabled = true
		pm.emission_texture = pm.albedo_texture
		pm.emission_energy_multiplier = 0.25
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.84, 0.56)
		q.mesh = qm
		q.material_override = pm
		q.position = Vector3(0, glass_top - 0.36, -hd + 0.025)
		add_child(q)
	# 재고 상자 선반 2단 × 3개
	var sz := (z_back - 0.01) - (-hd + 0.03)
	for row in 2:
		var y0 := base_h - 0.02 + row * 0.19
		_box(Vector3(ix * 2.0, 0.012, sz + 0.02), Vector3(0, y0 - 0.006, (z_back + -hd) * 0.5), shelf_mat)
		for k in 3:
			var id := String(ids[(k + row) % ids.size()])
			_display_box(id, Vector3(-0.29 + k * 0.29, y0, (z_back + -hd) * 0.5 + 0.01))


func _display_box(id: String, pos: Vector3) -> void:
	var item := PrizeCatalog.get_item(id)
	if item.is_empty():
		return
	var scene := PrizeFactory.load_scene(String(item["model"]))
	if scene == null:
		return
	var inst := scene.instantiate()
	var mat := PrizeFactory._rigid_material("printed", item["colorways"][0], item)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.material_override = mat
		copy.scale = Vector3.ONE * 0.8
		copy.position = pos
		add_child(copy)
	inst.free()


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
	var floor_white := _mat(Color(0.95, 0.96, 0.97), 0.15)
	floor_white.clearcoat_enabled = true
	var slope := _box(Vector3(ix * 2.0, 0.03, len + 0.05), Vector3(0, (base_h - 0.04 + bin_y + 0.03) * 0.5, (z_back + z_front) * 0.5), floor_white, false, null, Vector3(ang, 0, 0))
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
	# 구덩이 둘레 벽(상자가 기계 밖으로 빠져나가지 않게)
	var pit_h := base_h - bin_y + 0.1
	_wall(Vector3(0.04, pit_h, z_front - z_back + 0.3), Vector3(-ix - 0.02, bin_y - 0.05 + pit_h * 0.5, (z_front + z_back) * 0.5 + 0.1))
	_wall(Vector3(0.04, pit_h, z_front - z_back + 0.3), Vector3(ix + 0.02, bin_y - 0.05 + pit_h * 0.5, (z_front + z_back) * 0.5 + 0.1))
	_wall(Vector3(ix * 2.0 + 0.08, pit_h, 0.04), Vector3(0, bin_y - 0.05 + pit_h * 0.5, z_back - 0.03))
	_wall(Vector3(ix * 2.0 + 0.08, 0.04, z_front - z_back + 0.3), Vector3(0, bin_y - 0.07, (z_front + z_back) * 0.5 + 0.1))
	# 오른쪽 앞(배출구 옆)은 막혀 있으므로 왼쪽으로 흘러가게 하는 경사 칸막이
	_box(Vector3(0.02, 0.32, 0.3), Vector3(chute_x + 0.01, bin_y + 0.16, z_front - 0.12), inner, true, null, Vector3(0, -0.5, 0))
	_rebuild_bars()


func _layout() -> String:
	return String(settings.get("bridge_layout", "2bar"))


## 다리(봉) 배치: [시작점, 끝점] 목록 (기계 로컬 좌표, 봉 윗면 기준 높이)
## 실제 일본 기계처럼 봉은 좌우(가로)로 놓이고, 상자는 앞뒤 봉에 걸쳐 놓인다.
func _bar_lines() -> Array:
	var g := _gap()
	var x0 := -ix + 0.025
	var x1 := ix - 0.025
	match _layout():
		"3bar":
			var h := g * 0.72
			return [[Vector3(x0, bar_y, h), Vector3(x1, bar_y, h)], [Vector3(x0, bar_y, 0), Vector3(x1, bar_y, 0)], [Vector3(x0, bar_y, -h), Vector3(x1, bar_y, -h)]]
		"v":
			# ハの字: 왼쪽은 좁고 오른쪽으로 갈수록 벌어진다
			return [[Vector3(x0, bar_y, g * 0.5), Vector3(x1, bar_y, g * 0.5)], [Vector3(x0, bar_y, -g * 0.5 + 0.03), Vector3(x1, bar_y, -g * 0.5 - 0.07)]]
		"step":
			# 단차: 뒤쪽 봉이 더 높다
			return [[Vector3(x0, bar_y, g * 0.5), Vector3(x1, bar_y, g * 0.5)], [Vector3(x0, bar_y + 0.04, -g * 0.5), Vector3(x1, bar_y + 0.04, -g * 0.5)]]
	return [[Vector3(x0, bar_y, g * 0.5), Vector3(x1, bar_y, g * 0.5)], [Vector3(x0, bar_y, -g * 0.5), Vector3(x1, bar_y, -g * 0.5)]]


var _built_sig := ""


func _rod(a: Vector3, b: Vector3, r: float, mat: Material, collide: bool, pm: PhysicsMaterial = null) -> void:
	var len := a.distance_to(b)
	var dir := (b - a) / len
	var basis := Basis(Quaternion(Vector3.UP, dir)) if abs(dir.dot(Vector3.UP)) < 0.999 else Basis()
	var xf := Transform3D(basis, (a + b) * 0.5)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = len
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	mi.transform = xf
	bars_root.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER_ENV
		if pm:
			sb.physics_material_override = pm
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = r
		cy.height = len
		cs.shape = cy
		sb.add_child(cs)
		sb.transform = xf
		bars_root.add_child(sb)


func _rebuild_bars() -> void:
	if bars_root:
		bars_root.free()
	bars_root = Node3D.new()
	bars_root.name = "Bars"
	add_child(bars_root)
	_built_sig = "%s_%.3f" % [_layout(), _gap()]
	var chrome := _mat(Color(0.88, 0.88, 0.9), 0.15, 1.0)
	var rubber := _mat(Color(0.08, 0.08, 0.1), 0.75)
	var alu := _mat(Color(0.72, 0.73, 0.76), 0.3, 0.8)
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0  # 봉에 씌운 미끄럼 방지 고무
	var r := 0.0135
	# 양옆 벽에 붙은 세로 프레임(봉을 고정하는 브래킷 레일)
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (ix - 0.012)
		_box(Vector3(0.02, bar_y - base_h + 0.16, 0.05), Vector3(fx, (base_h - 0.06 + bar_y + 0.1) * 0.5, z_front - 0.06), alu, false, bars_root)
		_box(Vector3(0.02, bar_y - base_h + 0.16, 0.05), Vector3(fx, (base_h - 0.06 + bar_y + 0.1) * 0.5, z_back + 0.06), alu, false, bars_root)
		_box(Vector3(0.02, 0.04, z_front - z_back - 0.06), Vector3(fx, bar_y - 0.05, (z_front + z_back) * 0.5), alu, false, bars_root)
	for line in _bar_lines():
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var ca := a - Vector3(0, r, 0)
		var cb := b - Vector3(0, r, 0)
		_rod(ca, cb, r, chrome, true, pm)
		# 가운데 미끄럼 방지 고무 + 양 끝 고정 브래킷
		_rod(ca.lerp(cb, 0.2), ca.lerp(cb, 0.8), r + 0.0018, rubber, false)
		for e in [ca, cb]:
			var ep: Vector3 = e
			_box(Vector3(0.03, 0.05, 0.035), Vector3(sign(ep.x) * (ix - 0.02), ep.y - 0.012, ep.z), alu, false, bars_root)
	# 뒤쪽 가로 철제 가드(상자가 뒤로 넘어가 끼지 않도록)와 앞쪽 낮은 가드
	_rod(Vector3(-ix + 0.02, bar_y + 0.09, z_back + 0.04), Vector3(ix - 0.02, bar_y + 0.09, z_back + 0.04), 0.01, chrome, true)
	_rod(Vector3(-ix + 0.02, bar_y - 0.07, z_front - 0.03), Vector3(ix - 0.02, bar_y - 0.07, z_front - 0.03), 0.009, chrome, false)


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
	# 배출구 앞 투명 덮개(밀어서 여는 문): 상자가 굴러 밖으로 튀어나가지 않게
	_wall(Vector3(cw, open_h, 0.02), Vector3((-ix + chute_x) * 0.5, bin_y + open_h * 0.5, D * 0.5 + 0.035))
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
		var x := 0.0 if count == 1 else (-0.2 + i * 0.4)
		if _layout() == "v" and count == 1:
			x = -0.18
		_place_on_bars(id, x, rng)


## 상자를 눕힌 자세(창이 위, 긴 변이 앞뒤)로 만드는 회전
const BOX_LAY := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))


func _place_on_bars(id: String, x: float, rng: RandomNumberGenerator) -> Prize:
	# 실제 일본 기계처럼 상자는 눕혀서(창이 위) 앞뒤 봉에 걸쳐 놓는다
	var top := bar_y + (0.04 if _layout() == "step" else 0.0)
	var p := add_prize(id, to_global(Vector3(x, top + 0.2, 0)), 0.0, null)
	if p == null:
		return null
	var b := BOX_LAY
	if rng.randf() < 0.5:
		b = Basis(Vector3.UP, PI) * b
	var half_h := 0.075
	var center := Vector3(x + rng.randf_range(-0.015, 0.015), top + half_h + 0.004, rng.randf_range(-0.01, 0.01))
	# 모델 원점은 상자 바닥면(모델 -Y 쪽) 중앙 → 중심에서 모델 +Y 방향 반대로 0.10
	var origin := center - b * Vector3(0, 0.10, 0)
	p.global_transform = global_transform * Transform3D(b, origin)
	return p


func _return_to_bed(p: Prize) -> void:
	if not is_instance_valid(p):
		return
	var id := p.prize_id
	p.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_place_on_bars(id, 0.0, rng)


func _on_settings_changed(id: String) -> void:
	super._on_settings_changed(id)
	if id == machine_id and state == State.IDLE and bars_root:
		if _built_sig != "%s_%.3f" % [_layout(), _gap()]:
			_rebuild_bars()
			# 새 다리 위에 상자를 다시 올려 둔다
			var had := get_prizes().size()
			clear_prizes()
			await get_tree().process_frame
			fill_random(max(had, 1))
			save_layout()
