class_name Shop
extends Node3D
## 뽑기방 전체: 방(바닥·벽·천장·조명), 기계 배치, 지폐교환기, 캡슐뽑기, 전시장, 카운터, 소품

var machines: Array = []
var showcase: Showcase
var hud

const RX := 5.2   # 방 반너비(x)
const RZ := 4.4   # 방 반깊이(z)
const RH := 3.1   # 천장 높이


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_machines()
	_build_side_props()
	_build_showcase()
	_build_counter()
	_build_decor()


# ------------------------------------------------------------------ 환경/조명
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.04, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.92, 0.96)
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 0.95
	e.ssao_enabled = true
	e.ssao_radius = 0.6
	e.ssao_intensity = 1.6
	e.ssr_enabled = true
	e.ssr_max_steps = 48
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.3
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.08
	we.environment = e
	add_child(we)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(RX * 2, RH, RZ * 2)
	probe.position = Vector3(0, RH * 0.5, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)
	# 천장 조명(패널 + 옴니)
	var panel := Build.glow(Color(1.0, 0.98, 0.95), 2.2)
	for x in [-3.0, 0.0, 3.0]:
		for z in [-2.5, 0.2, 2.8]:
			Build.box(self, Vector3(1.0, 0.03, 0.5), Vector3(x, RH - 0.02, z), panel)
			var l := OmniLight3D.new()
			l.position = Vector3(x, RH - 0.25, z)
			l.omni_range = 4.2
			l.light_energy = 0.55
			l.light_color = Color(1.0, 0.95, 0.92)
			add_child(l)


# ------------------------------------------------------------------ 방
func _build_room() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://assets/textures/shop/floor_tiles.png")
	floor_mat.uv1_scale = Vector3(RX * 2 / 2.4, RZ * 2 / 2.4, 1)
	floor_mat.roughness_texture = load("res://assets/textures/shop/floor_rough.png")
	floor_mat.roughness = 0.35
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
	wall.albedo_texture = load("res://assets/textures/shop/wallpaper.png")
	wall.uv1_scale = Vector3(6, 2, 1)
	wall.roughness = 0.85
	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.albedo_texture = load("res://assets/textures/shop/ceiling.png")
	ceil_mat.uv1_scale = Vector3(5, 4, 1)
	ceil_mat.roughness = 0.9
	var skirting := Build.mat(Color(1.0, 0.45, 0.66), 0.4)
	var walls := [
		[Vector3(RX * 2, RH, 0.2), Vector3(0, RH * 0.5, -RZ - 0.1)],
		[Vector3(RX * 2, RH, 0.2), Vector3(0, RH * 0.5, RZ + 0.1)],
		[Vector3(0.2, RH, RZ * 2), Vector3(-RX - 0.1, RH * 0.5, 0)],
		[Vector3(0.2, RH, RZ * 2), Vector3(RX + 0.1, RH * 0.5, 0)],
	]
	for w in walls:
		Build.box(self, w[0], w[1], wall, 1 | 8)
	Build.box(self, Vector3(RX * 2, 0.02, RZ * 2), Vector3(0, RH + 0.01, 0), ceil_mat)
	# 걸레받이
	Build.box(self, Vector3(RX * 2, 0.12, 0.02), Vector3(0, 0.06, -RZ + 0.01), skirting)
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
	var bz := -RZ + 0.52
	_add_machine("big_1", "big", Vector3(-2.7, 0, bz), 0, Color(1.0, 0.45, 0.66), {"name": "왕인형 뽑기", "prize_ids": ["bear", "bunny", "penguin", "dino", "cat", "panda", "shiba", "shark", "frog"]}, 18)
	_add_machine("big_2", "big", Vector3(-1.5, 0, bz), 0, Color(0.35, 0.78, 0.68), {"name": "바다·공룡 친구들", "prize_ids": ["dino", "penguin", "shark", "frog"]}, 16)
	_add_machine("big_3", "big", Vector3(-0.3, 0, bz), 0, Color(0.62, 0.5, 0.92), {"name": "멍냥·판다 하우스", "prize_ids": ["shiba", "panda", "bunny", "cat"], "payout_mode": "revenue"}, 16)
	_add_machine("big_4", "big", Vector3(0.9, 0, bz), 0, Color(1.0, 0.62, 0.3), {"name": "피규어 박스", "prize_ids": ["figure_box", "bear"], "power_grab": 85, "power_top": 40}, 12)
	var sx := -RX + 0.4
	_add_machine("small_1", "small", Vector3(sx, 0, -2.4), PI / 2, Color(0.4, 0.68, 1.0), {"name": "삐약이 미니뽑기", "prize_ids": ["chick", "duck", "hamster", "whale"]}, 22)
	_add_machine("small_2", "small", Vector3(sx, 0, -1.6), PI / 2, Color(1.0, 0.78, 0.25), {"name": "키링 뽑기", "prize_ids": ["mini_bear", "mini_bunny"], "prong_count": 2, "open_angle": 34}, 18)
	_add_machine("small_3", "small", Vector3(sx, 0, -0.8), PI / 2, Color(1.0, 0.5, 0.6), {"name": "과자·캡슐 뽑기", "prize_ids": ["snack", "capsule", "mochi"], "control_mode": "2button"}, 22)
	_add_machine("small_4", "small", Vector3(sx, 0, 0.0), PI / 2, Color(0.55, 0.85, 0.45), {"name": "모찌볼 천국", "prize_ids": ["mochi", "chick", "duck", "mini_bear", "hamster", "whale", "mini_frog"]}, 22)
	# 일본식 프라이즈 피규어 기계(다리 세팅) 2대
	var bx := -RX + 0.52
	_add_machine("bridge_1", "bridge", Vector3(bx, 0, 1.15), PI / 2, Color(0.92, 0.18, 0.25), {"name": "UFO 피규어 · 미루", "prize_ids": ["jp_figure_a"]}, 1)
	_add_machine("bridge_2", "bridge", Vector3(bx, 0, 2.3), PI / 2, Color(0.2, 0.45, 0.95), {"name": "UFO 피규어 · 보노", "prize_ids": ["jp_figure_b"], "bridge_gap": 0.18}, 1)
	Build.text(self, "일본식 피규어 존", Vector3(-RX + 0.03, 2.62, 1.75), 90, 0.0018, Color(1.0, 0.95, 0.7), Color(0.9, 0.2, 0.3), "res://assets/fonts/BlackHanSans-Regular.ttf").rotation.y = PI / 2


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
	# 음료 자판기(장식)
	var vm := Node3D.new()
	vm.position = Vector3(RX - 0.4, 0, 3.6)
	vm.rotation.y = -PI / 2
	add_child(vm)
	Build.box(vm, Vector3(0.9, 1.85, 0.7), Vector3(0, 0.925, 0), Build.mat(Color(0.9, 0.15, 0.2), 0.35, 0.2))
	Build.box(vm, Vector3(0.6, 1.1, 0.02), Vector3(-0.08, 1.15, 0.351), Build.glow(Color(0.85, 0.95, 1.0), 0.8))
	for r in 4:
		for c in 5:
			var can := Build.cyl(vm, 0.035, 0.12, Vector3(-0.32 + c * 0.12, 0.7 + r * 0.26, 0.33), Build.mat(Color.from_hsv(randf(), 0.6, 0.95), 0.3, 0.6))
	Build.text(vm, "시원한 음료", Vector3(0, 1.78, 0.36), 50, 0.0012, Color(1, 1, 1))
	Build.box(vm, Vector3(0.12, 0.4, 0.02), Vector3(0.33, 1.15, 0.352), Build.mat(Color(0.15, 0.15, 0.18), 0.4))
	Build.blocker(vm, Vector3(0.9, 1.9, 0.7), Vector3(0, 0.95, 0))


# ------------------------------------------------------------------ 전시장
func _build_showcase() -> void:
	showcase = Showcase.new()
	showcase.name = "Showcase"
	showcase.position = Vector3(0, 0, 0)
	showcase.setup([
		[Vector3(2.45, 0, -RZ + 0.25), 0.0, "big"],
		[Vector3(3.7, 0, -RZ + 0.25), 0.0, "big"],
		[Vector3(RX - 0.25, 0, -2.6), -PI / 2, "small"],
	])
	add_child(showcase)
	showcase.build_board(Vector3(RX - 0.03, 1.45, -1.2), -PI / 2)
	# 전시장 바닥 러그 & 차단 줄 느낌의 낮은 경계
	var rug := Build.box(self, Vector3(3.6, 0.008, 2.6), Vector3(3.2, 0.004, -2.9), Build.mat(Color(0.98, 0.82, 0.88), 0.95))
	rug.name = "ShowcaseRug"


# ------------------------------------------------------------------ 카운터
func _build_counter() -> void:
	var c := OwnerCounter.new()
	c.position = Vector3(-3.6, 0, 3.4)
	add_child(c)


func _build_decor() -> void:
	Build.decor(self, "loungeSofa", Vector3(-1.0, 0, 1.6), 1.8, PI)
	Build.blocker(self, Vector3(1.8, 0.8, 0.8), Vector3(-1.0, 0.4, 1.6))
	Build.decor(self, "trashcan", Vector3(0.5, 0, 1.9), 1.7)
	Build.decor(self, "pottedPlant", Vector3(-RX + 0.35, 0, RZ - 0.35), 2.0)
	Build.decor(self, "pottedPlant", Vector3(RX - 0.35, 0, -0.55), 2.0)
	Build.decor(self, "pottedPlant", Vector3(1.75, 0, -RZ + 0.35), 1.8)
	Build.decor(self, "speaker", Vector3(-RX + 0.3, 2.2, -RZ + 0.3), 1.3, PI / 4)
	Build.decor(self, "speaker", Vector3(RX - 0.3, 2.2, RZ - 0.3), 1.3, -3 * PI / 4)
	Build.decor(self, "rugRound", Vector3(-1.0, 0.003, 1.2), 2.4)
	Build.decor(self, "stoolBar", Vector3(-2.2, 0, 1.0), 1.6)


func save_all() -> void:
	for m in machines:
		m.save_layout()
	Game.save_game()
