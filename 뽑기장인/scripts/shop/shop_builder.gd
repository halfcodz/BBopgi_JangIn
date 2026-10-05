class_name Shop
extends Node3D
## 뽑기방 전체: 방(바닥·벽·천장·조명), 기계 배치, 지폐교환기, 캡슐뽑기, 전시장, 카운터, 소품

var machines: Array = []
var showcase: Showcase
var hud

const RX := 7.0   # 방 반너비(x)
const RZ := 5.0   # 방 반깊이(z)
const RH := 3.1   # 천장 높이
# 개인 전시실(뒷벽 뒤 별도 방)
const DOOR_X0 := 4.3
const DOOR_X1 := 5.7
const DOOR_H := 2.4
const GX0 := 2.6
const GZ1 := -10.2


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_machines()
	_build_side_props()
	_build_showcase()
	_build_counter()
	_build_decor()
	if Game.touch:
		# 휴대폰: 벽·바닥 장식 같은 움직이지 않는 부품을 재질별로 합친다
		RenderBatcher.merge_static.call_deferred(self, RenderBatcher.referenced_nodes(self))
		RenderBatcher.hide_small_labels_far.call_deferred(self, 6.0)


# ------------------------------------------------------------------ 환경/조명
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.04, 0.03, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.85, 1.0)
	e.ambient_light_energy = 0.26 if not Game.web else 0.55  # 웹은 천장 조명 15개를 빼는 대신 주변광을 밝게
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 0.95
	e.ssao_enabled = true
	e.ssao_radius = 0.6
	e.ssao_intensity = 1.6
	e.ssr_enabled = false  # 화면 공간 반사는 움직일 때 반짝이며 떨려 보여서 끄고, 반사 프로브만 쓴다
	e.glow_enabled = true
	# 네온 뽑기방: 발광 띠가 은은하게 번지도록
	e.glow_intensity = 0.85
	e.glow_strength = 1.1
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	we.environment = e
	add_child(we)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(RX * 2, RH, RZ * 2)
	probe.position = Vector3(0, RH * 0.5, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	# 천장 네온 라인(사진 속 분홍·보라 줄 조명) + 은은한 색 조명
	var neon_cols := [Color(1.0, 0.35, 0.85), Color(0.7, 0.4, 1.0), Color(0.35, 0.85, 1.0)]
	for i in 6:
		var z := -RZ + 0.8 + i * (RZ * 2 - 1.6) / 5.0
		Build.box(self, Vector3(RX * 2 - 0.6, 0.025, 0.035), Vector3(0, RH - 0.03, z), Build.glow(neon_cols[i % 3], 4.0))
	for x in [-RX + 0.5, RX - 0.5]:
		Build.box(self, Vector3(0.035, 0.025, RZ * 2 - 0.6), Vector3(x, RH - 0.03, 0), Build.glow(neon_cols[0], 4.0))
	for x in ([] if Game.web else [-5.0, -2.5, 0.0, 2.5, 5.0]):
		for z in [-3.2, 0.0, 3.2]:
			var l := OmniLight3D.new()
			l.position = Vector3(x, RH - 0.3, z)
			l.omni_range = 4.4
			l.light_energy = 0.5
			l.light_color = Color(1.0, 0.8, 0.98) if int(x + z) % 2 == 0 else Color(0.85, 0.82, 1.0)
			add_child(l)


# ------------------------------------------------------------------ 방
func _build_room() -> void:
	var floor_mat := StandardMaterial3D.new()
	# 광택 흑백 체크 바닥(네온이 비친다)
	floor_mat.albedo_texture = load("res://assets/textures/shop/floor_bw.png")
	floor_mat.uv1_scale = Vector3(RX * 2 / 1.2, RZ * 2 / 1.2, 1)
	floor_mat.roughness = 0.1
	floor_mat.metallic_specular = 0.7
	floor_mat.clearcoat_enabled = true
	floor_mat.clearcoat = 0.8
	floor_mat.clearcoat_roughness = 0.05
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(RX * 2, RZ * 2)
	fl.mesh = pm
	fl.material_override = floor_mat
	add_child(fl)
	var fb := StaticBody3D.new()
	fb.collision_layer = 1 | 8
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(RX * 2 + 2, 0.2, RZ * 2 + 2)
	fcs.shape = fbs
	fcs.position.y = -0.1
	fb.add_child(fcs)
	add_child(fb)

	var wall := StandardMaterial3D.new()
	wall.albedo_texture = load("res://assets/textures/shop/wall_neon.png")
	wall.uv1_scale = Vector3(7, 1, 1)
	wall.roughness = 0.6
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_texture = load("res://assets/textures/shop/ceiling_dark.png")
	ceil_mat.uv1_scale = Vector3(12, 10, 1)
	ceil_mat.roughness = 0.7
	var skirting := Build.glow(Color(1.0, 0.4, 0.85), 2.5)  # 바닥 둘레 네온 띠
	# 뒷벽에는 전시실로 들어가는 문(DOOR_X0~DOOR_X1)이 뚫려 있다
	var walls := [
		[Vector3(DOOR_X0 + RX, RH, 0.2), Vector3((-RX + DOOR_X0) * 0.5, RH * 0.5, -RZ - 0.1)],
		[Vector3(RX - DOOR_X1, RH, 0.2), Vector3((DOOR_X1 + RX) * 0.5, RH * 0.5, -RZ - 0.1)],
		[Vector3(DOOR_X1 - DOOR_X0, RH - DOOR_H, 0.2), Vector3((DOOR_X0 + DOOR_X1) * 0.5, (DOOR_H + RH) * 0.5, -RZ - 0.1)],
		[Vector3(RX * 2, RH, 0.2), Vector3(0, RH * 0.5, RZ + 0.1)],
		[Vector3(0.2, RH, RZ * 2), Vector3(-RX - 0.1, RH * 0.5, 0)],
		[Vector3(0.2, RH, RZ * 2), Vector3(RX + 0.1, RH * 0.5, 0)],
	]
	for w in walls:
		Build.box(self, w[0], w[1], wall, 1 | 8)
	Build.box(self, Vector3(RX * 2, 0.02, RZ * 2), Vector3(0, RH + 0.01, 0), ceil_mat)
	# 벽 위쪽 둘레 네온 라인
	var wall_neon := Build.glow(Color(0.75, 0.45, 1.0), 3.0)
	Build.box(self, Vector3(RX * 2 - 0.1, 0.03, 0.02), Vector3(0, RH - 0.25, -RZ + 0.015), wall_neon)
	Build.box(self, Vector3(RX * 2 - 0.1, 0.03, 0.02), Vector3(0, RH - 0.25, RZ - 0.015), wall_neon)
	Build.box(self, Vector3(0.02, 0.03, RZ * 2 - 0.1), Vector3(-RX + 0.015, RH - 0.25, 0), wall_neon)
	Build.box(self, Vector3(0.02, 0.03, RZ * 2 - 0.1), Vector3(RX - 0.015, RH - 0.25, 0), wall_neon)
	# 걸레받이
	Build.box(self, Vector3(DOOR_X0 + RX, 0.12, 0.02), Vector3((-RX + DOOR_X0) * 0.5, 0.06, -RZ + 0.01), skirting)
	Build.box(self, Vector3(RX - DOOR_X1, 0.12, 0.02), Vector3((DOOR_X1 + RX) * 0.5, 0.06, -RZ + 0.01), skirting)
	Build.box(self, Vector3(RX * 2, 0.12, 0.02), Vector3(0, 0.06, RZ - 0.01), skirting)
	Build.box(self, Vector3(0.02, 0.12, RZ * 2), Vector3(-RX + 0.01, 0.06, 0), skirting)
	Build.box(self, Vector3(0.02, 0.12, RZ * 2), Vector3(RX - 0.01, 0.06, 0), skirting)
	# 출입문(유리문)
	var door := Node3D.new()
	door.position = Vector3(2.2, 0, RZ - 0.02)
	add_child(door)
	Build.box(door, Vector3(1.7, 2.3, 0.05), Vector3(0, 1.15, 0), Build.mat(Color(0.75, 0.76, 0.8), 0.25, 0.9))
	Build.box(door, Vector3(0.75, 2.1, 0.06), Vector3(-0.4, 1.12, 0), Build.glass(Color(0.6, 0.75, 0.9, 0.35)))
	Build.box(door, Vector3(0.75, 2.1, 0.06), Vector3(0.4, 1.12, 0), Build.glass(Color(0.6, 0.75, 0.9, 0.35)))
	Build.box(door, Vector3(0.03, 0.5, 0.08), Vector3(-0.06, 1.1, -0.03), Build.mat(Color(0.9, 0.9, 0.9), 0.2, 1.0))
	Build.box(door, Vector3(0.03, 0.5, 0.08), Vector3(0.06, 1.1, -0.03), Build.mat(Color(0.9, 0.9, 0.9), 0.2, 1.0))
	Build.text(door, "PUSH 미세요", Vector3(0, 1.45, -0.04), 40, 0.0012, Color(1, 1, 1)).rotation.y = PI
	Build.text(door, "24시 무인 인형뽑기", Vector3(0, 2.0, -0.04), 44, 0.0012, Color(1, 0.9, 0.5)).rotation.y = PI

	# 네온 간판
	var neon := Build.text(self, "뽑기장인", Vector3(-1.0, 2.62, -RZ + 0.03), 220, 0.0022, Color(1.0, 0.82, 0.92), Color(1.0, 0.25, 0.6), "res://assets/fonts/BlackHanSans-Regular.ttf")
	neon.outline_size = 40
	neon.shaded = false
	var nl := OmniLight3D.new()
	nl.position = Vector3(-1.0, 2.6, -RZ + 0.4)
	nl.light_color = Color(1.0, 0.35, 0.65)
	nl.light_energy = 1.2
	nl.omni_range = 3.0
	add_child(nl)
	var neon2 := Build.text(self, "♥ 오늘도 득템 ♥", Vector3(-RX + 0.03, 2.55, -0.8), 110, 0.0018, Color(0.8, 0.95, 1.0), Color(0.2, 0.6, 1.0), "res://assets/fonts/Jua-Regular.ttf")
	neon2.rotation.y = PI / 2
	neon2.outline_size = 30
	neon2.shaded = false
	# 포스터
	_poster("poster_tip", Vector3(RX - 0.02, 1.7, -0.3), -PI / 2)
	_poster("poster_new", Vector3(-1.2, 1.75, RZ - 0.02), PI)
	_poster("poster_rule", Vector3(0.3, 1.75, RZ - 0.02), PI)


func _poster(tex: String, pos: Vector3, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.84)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/shop/%s.png" % tex)
	m.roughness = 0.5
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)


# ------------------------------------------------------------------ 인형뽑기 기계들
func _add_machine(id: String, kind: String, pos: Vector3, rot_y: float, color: Color, preset: Dictionary, fill: int) -> void:
	var m: ClawMachine = BridgeMachine.new() if kind == "bridge" else ClawMachine.new()
	m.name = id
	m.machine_id = id
	m.kind = kind
	m.theme_color = color
	m.preset = preset
	m.initial_fill = fill
	m.position = pos
	m.rotation.y = rot_y
	add_child(m)
	machines.append(m)


func _build_machines() -> void:
	# 뒷벽: 큰 인형 기계 + 전자기기 경품 기계
	var bz := -RZ + 0.52
	_add_machine("big_1", "big", Vector3(-5.6, 0, bz), 0, Color(1.0, 0.55, 0.82), {"name": "왕인형 뽑기", "prize_ids": ["bear", "bunny", "penguin", "dino", "cat", "panda", "shiba", "chibi_cat", "chibi_bunny"]}, 30)
	_add_machine("big_2", "big", Vector3(-4.4, 0, bz), 0, Color(0.74, 0.58, 1.0), {"name": "바다·공룡 친구들", "prize_ids": ["dino", "penguin", "shark", "frog"]}, 26)
	_add_machine("big_3", "big", Vector3(-3.2, 0, bz), 0, Color(0.98, 0.7, 0.9), {"name": "멍냥·판다 하우스", "prize_ids": ["shiba", "panda", "chibi_cat", "cat"], "payout_mode": "revenue"}, 26)
	_add_machine("big_4", "big", Vector3(-2.0, 0, bz), 0, Color(0.55, 0.78, 1.0), {"name": "피규어 박스", "prize_ids": ["figure_box", "bear"], "power_grab": 85, "power_top": 40}, 20)
	_add_machine("big_5", "big", Vector3(-0.8, 0, bz), 0, Color(0.6, 0.92, 0.85), {"name": "경품 대잔치", "prize_ids": ["gift_earbuds", "gift_powerbank", "gift_fan", "gift_lamp"], "power_grab": 85, "power_lift": 75, "power_top": 35}, 20)
	_add_machine("big_6", "big", Vector3(0.4, 0, bz), 0, Color(0.88, 0.5, 0.95), {"name": "스피커·무드등", "prize_ids": ["gift_speaker", "gift_lamp", "gift_earbuds"], "power_grab": 90, "power_lift": 80, "power_top": 40}, 16)
	# 왼쪽 벽: 작은 기계
	var sx := -RX + 0.4
	_add_machine("small_1", "small", Vector3(sx, 0, -3.6), PI / 2, Color(1.0, 0.68, 0.75), {"name": "삐약이 미니뽑기", "prize_ids": ["chick", "duck", "hamster", "whale"]}, 36)
	_add_machine("small_2", "small", Vector3(sx, 0, -2.8), PI / 2, Color(0.66, 0.66, 1.0), {"name": "키링 뽑기", "prize_ids": ["mini_bear", "mini_bunny"], "prong_count": 2, "open_angle": 34}, 30)
	_add_machine("small_3", "small", Vector3(sx, 0, -2.0), PI / 2, Color(1.0, 0.55, 0.82), {"name": "과자·캡슐 뽑기", "prize_ids": ["snack", "capsule", "mochi"], "control_mode": "2button"}, 36)
	_add_machine("small_4", "small", Vector3(sx, 0, -1.2), PI / 2, Color(0.74, 0.58, 1.0), {"name": "모찌볼 천국", "prize_ids": ["mochi", "chick", "duck", "mini_bear", "hamster", "whale", "mini_frog"]}, 36)
	# 가운데 섬: 굿즈 미니 기계 6대(키캡·말랑이·팝잇·슬라임)
	var gz := -1.5
	var goods := [
		["small_5", "키캡 키링", Color(0.88, 0.5, 0.95), ["keycap_heart", "keycap_cat"], {"prong_count": 2, "open_angle": 34}, 43],
		["small_6", "말랑이 천국", Color(1.0, 0.68, 0.75), ["squishy_bread", "squishy_peach", "squishy_paw", "mochi"], {}, 36],
		["small_7", "냥발 말랑이", Color(0.66, 0.66, 1.0), ["squishy_paw", "squishy_peach"], {}, 36],
		["small_8", "팝잇·슬라임", Color(1.0, 0.55, 0.82), ["popit", "slime_cup"], {}, 33],
		["small_9", "왕키캡 스페셜", Color(0.74, 0.58, 1.0), ["keycap_cat", "keycap_heart"], {"control_mode": "2button", "prong_count": 2, "open_angle": 34}, 40],
		["small_10", "랜덤 굿즈", Color(0.98, 0.7, 0.9), ["keycap_heart", "squishy_bread", "popit", "slime_cup", "squishy_paw", "keycap_cat", "capsule"], {}, 40],
	]
	for i in goods.size():
		var g: Array = goods[i]
		var preset: Dictionary = {"name": g[1], "prize_ids": g[3]}
		preset.merge(g[4])
		_add_machine(g[0], "small", Vector3(-4.4 + i * 0.76, 0, gz), 0, g[2], preset, g[5])
	Build.text(self, "★ 키캡 · 말랑이 · 피젯 존 ★", Vector3(-2.5, 2.25, gz + 0.1), 80, 0.0016, Color(1.0, 0.95, 0.7), Color(0.6, 0.3, 0.9), "res://assets/fonts/BlackHanSans-Regular.ttf")
	# 가운데 섬 2: 경품·인형 큰 기계
	var cz := 1.3
	_add_machine("big_7", "big", Vector3(1.2, 0, cz), 0, Color(0.98, 0.7, 0.9), {"name": "이어폰·배터리", "prize_ids": ["gift_earbuds", "gift_powerbank"], "power_grab": 85, "power_lift": 75, "power_top": 35}, 16)
	_add_machine("big_8", "big", Vector3(2.4, 0, cz), 0, Color(0.55, 0.78, 1.0), {"name": "인형+경품 믹스", "prize_ids": ["chibi_bunny", "bunny", "gift_fan", "gift_lamp", "chibi_cat"]}, 23)
	_add_machine("big_9", "big", Vector3(3.6, 0, cz), 0, Color(0.6, 0.92, 0.85), {"name": "몽글몽글 마스코트", "prize_ids": ["chibi_cat", "chibi_bunny"]}, 26)
	# 일본식 UFO 피규어 존: 두 칸짜리 기계 2쌍(실제 매장처럼 나란히 붙여 둔다)
	var bx := -RX + 0.62
	var jp := [
		["bridge_1", "UFO 피규어 · 미루", Color(0.25, 0.55, 1.0), ["jp_figure_a"], 0.2, {}],
		["bridge_2", "UFO 피규어 · 보노", Color(0.25, 0.55, 1.0), ["jp_figure_b"], 1.21, {"bridge_layout": "3bar"}],
		["bridge_3", "UFO 피규어 · 냥냥", Color(0.95, 0.35, 0.6), ["jp_figure_c"], 2.6, {}],
		["bridge_4", "UFO 피규어 · 루루", Color(0.95, 0.35, 0.6), ["jp_figure_d"], 3.61, {"bridge_layout": "v"}],
	]
	for j in jp:
		var preset2: Dictionary = {"name": j[1], "prize_ids": j[3]}
		preset2.merge(j[5])
		_add_machine(j[0], "bridge", Vector3(bx, 0, j[4]), PI / 2, j[2], preset2, 1)
	Build.text(self, "일본식 UFO 피규어 존", Vector3(-RX + 0.03, 2.62, 1.9), 90, 0.0018, Color(1.0, 0.95, 0.7), Color(0.2, 0.4, 0.95), "res://assets/fonts/BlackHanSans-Regular.ttf").rotation.y = PI / 2


# ------------------------------------------------------------------ 교환기 / 캡슐뽑기 / 자판기
func _build_side_props() -> void:
	var ch := BillChanger.new()
	ch.position = Vector3(RX - 0.3, 0, 2.6)
	ch.rotation.y = -PI / 2
	add_child(ch)
	var gachas := [["동물 피규어", 1000, Color(0.98, 0.55, 0.3)], ["미니 키링", 1000, Color(0.45, 0.7, 1.0)],
		["럭키 스티커", 500, Color(0.6, 0.85, 0.45)], ["시크릿 피규어", 2000, Color(0.75, 0.5, 0.95)]]
	for i in gachas.size():
		var g := GachaMachine.new()
		g.title = gachas[i][0]
		g.price = gachas[i][1]
		g.color = gachas[i][2]
		var col := i % 2
		var row := i / 2
		g.position = Vector3(RX - 0.25, row * 0.88, 0.6 + col * 0.46)
		g.rotation.y = -PI / 2
		add_child(g)
	Build.box(self, Vector3(0.46, 0.02, 0.96), Vector3(RX - 0.25, 1.77, 0.83), Build.mat(Color(1, 1, 1), 0.3))
	Build.text(self, "캡슐뽑기", Vector3(RX - 0.02, 2.05, 0.83), 90, 0.0018, Color(1.0, 0.95, 0.6), Color(0.9, 0.4, 0.1), "res://assets/fonts/BlackHanSans-Regular.ttf").rotation.y = -PI / 2
	Build.blocker(self, Vector3(0.6, 1.8, 1.0), Vector3(RX - 0.25, 0.9, 0.83))
	# 음료 자판기(실제 모양, 1,000원에 음료를 사 마실 수 있다)
	var vm := VendingMachine.new()
	vm.position = Vector3(RX - 0.4, 0, 3.6)
	vm.rotation.y = -PI / 2
	add_child(vm)


# ------------------------------------------------------------------ 전시장
func _build_showcase() -> void:
	_build_gallery_room()
	showcase = Showcase.new()
	showcase.name = "Showcase"
	showcase.position = Vector3(0, 0, 0)
	var gz := GZ1 + 0.25
	showcase.setup([
		[Vector3(3.55, 0, gz), 0.0, "big"],
		[Vector3(4.8, 0, gz), 0.0, "big"],
		[Vector3(6.05, 0, gz), 0.0, "big"],
		[Vector3(GX0 + 0.25, 0, -8.7), PI / 2, "small"],
		[Vector3(GX0 + 0.25, 0, -7.35), PI / 2, "big"],
		[Vector3(RX - 0.25, 0, -8.7), -PI / 2, "small"],
	])
	add_child(showcase)
	showcase.build_board(Vector3(RX - 0.03, 1.45, -6.6), -PI / 2)


## 개인 전시실: 가게 뒷벽 문을 지나 들어가는 조용한 방(따뜻한 조명, 카펫, 진열장)
func _build_gallery_room() -> void:
	var w := RX - GX0
	var d := -RZ - GZ1
	var cx := (GX0 + RX) * 0.5
	var cz := (-RZ + GZ1) * 0.5
	# 바닥(분홍 카펫) + 충돌
	var carpet := Build.mat(Color(0.86, 0.66, 0.78), 0.95)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, d)
	fl.mesh = pm
	fl.material_override = carpet
	fl.position = Vector3(cx, 0.001, cz)
	add_child(fl)
	var fb := StaticBody3D.new()
	fb.collision_layer = 1 | 8
	var fcs := CollisionShape3D.new()
	var fbs := BoxShape3D.new()
	fbs.size = Vector3(w + 0.4, 0.2, d + 0.4)
	fcs.shape = fbs
	fb.add_child(fcs)
	fb.position = Vector3(cx, -0.1, cz)
	add_child(fb)
	# 벽·천장
	var wall := Build.mat(Color(0.97, 0.93, 0.95), 0.7)
	Build.box(self, Vector3(0.2, RH, d + 0.2), Vector3(GX0 - 0.1, RH * 0.5, cz), wall, 1 | 8)
	Build.box(self, Vector3(0.2, RH, d + 0.2), Vector3(RX + 0.1, RH * 0.5, cz), wall, 1 | 8)
	Build.box(self, Vector3(w + 0.4, RH, 0.2), Vector3(cx, RH * 0.5, GZ1 - 0.1), wall, 1 | 8)
	Build.box(self, Vector3(w + 0.4, 0.02, d), Vector3(cx, RH + 0.01, cz), Build.mat(Color(0.95, 0.92, 0.94), 0.8))
	# 문틀(금색) + 걸레받이
	var gold := Build.mat(Color(0.95, 0.78, 0.4), 0.25, 0.9)
	for x in [DOOR_X0, DOOR_X1]:
		Build.box(self, Vector3(0.06, DOOR_H, 0.24), Vector3(x, DOOR_H * 0.5, -RZ - 0.1), gold)
	Build.box(self, Vector3(DOOR_X1 - DOOR_X0 + 0.06, 0.06, 0.24), Vector3((DOOR_X0 + DOOR_X1) * 0.5, DOOR_H, -RZ - 0.1), gold)
	var base_trim := Build.mat(Color(0.75, 0.55, 0.65), 0.5)
	Build.box(self, Vector3(0.02, 0.1, d), Vector3(GX0 + 0.01, 0.05, cz), base_trim)
	Build.box(self, Vector3(0.02, 0.1, d), Vector3(RX - 0.01, 0.05, cz), base_trim)
	Build.box(self, Vector3(w, 0.1, 0.02), Vector3(cx, 0.05, GZ1 + 0.01), base_trim)
	# 따뜻한 조명: 천장 원형 등 + 간접 조명 띠
	for x in [GX0 + w * 0.3, GX0 + w * 0.7]:
		for z in [cz - d * 0.25, cz + d * 0.25]:
			Build.cyl(self, 0.22, 0.03, Vector3(x, RH - 0.015, z), Build.glow(Color(1.0, 0.95, 0.85), 2.5))
			var l := OmniLight3D.new()
			l.position = Vector3(x, RH - 0.35, z)
			l.omni_range = 4.0
			l.light_energy = 0.7
			l.light_color = Color(1.0, 0.92, 0.82)
			add_child(l)
	var cove := Build.glow(Color(1.0, 0.75, 0.9), 2.0)
	Build.box(self, Vector3(w - 0.1, 0.02, 0.02), Vector3(cx, RH - 0.06, GZ1 + 0.02), cove)
	Build.box(self, Vector3(0.02, 0.02, d - 0.1), Vector3(GX0 + 0.02, RH - 0.06, cz), cove)
	Build.box(self, Vector3(0.02, 0.02, d - 0.1), Vector3(RX - 0.02, RH - 0.06, cz), cove)
	# 가운데 원형 러그 + 의자
	Build.decor(self, "rugRound", Vector3(cx, 0.004, cz + 0.5), 2.6)
	Build.decor(self, "stoolBar", Vector3(cx - 0.5, 0, cz + 0.6), 1.4)
	Build.decor(self, "stoolBar", Vector3(cx + 0.5, 0, cz + 0.6), 1.4)
	Build.decor(self, "pottedPlant", Vector3(RX - 0.35, 0, -RZ - 0.4), 1.8)
	# 문 위 네온 간판(가게 쪽) + 안내
	var sign := Build.text(self, "♥ 나의 전시실 ♥", Vector3((DOOR_X0 + DOOR_X1) * 0.5, 2.65, -RZ + 0.03), 90, 0.0016, Color(1.0, 0.92, 0.98), Color(1.0, 0.35, 0.75), "res://assets/fonts/BlackHanSans-Regular.ttf")
	sign.outline_size = 24
	sign.shaded = false


# ------------------------------------------------------------------ 카운터
func _build_counter() -> void:
	var c := OwnerCounter.new()
	c.position = Vector3(-3.6, 0, 4.2)
	add_child(c)


func _build_decor() -> void:
	Build.decor(self, "loungeSofa", Vector3(-1.4, 0, 2.6), 1.8, PI)
	Build.blocker(self, Vector3(1.8, 0.8, 0.8), Vector3(-1.4, 0.4, 2.6))
	Build.decor(self, "trashcan", Vector3(0.1, 0, 2.9), 1.7)
	Build.decor(self, "pottedPlant", Vector3(-RX + 0.35, 0, RZ - 0.35), 2.0)
	Build.decor(self, "pottedPlant", Vector3(RX - 0.35, 0, -0.55), 2.0)
	Build.decor(self, "pottedPlant", Vector3(2.0, 0, -RZ + 0.35), 1.8)
	Build.decor(self, "speaker", Vector3(-RX + 0.3, 2.2, -RZ + 0.3), 1.3, PI / 4)
	Build.decor(self, "speaker", Vector3(RX - 0.3, 2.2, RZ - 0.3), 1.3, -3 * PI / 4)
	Build.decor(self, "rugRound", Vector3(-1.4, 0.003, 2.2), 2.4)
	Build.decor(self, "stoolBar", Vector3(-2.8, 0, 2.0), 1.6)


func save_all() -> void:
	for m in machines:
		m.save_layout()
	Game.save_game()
