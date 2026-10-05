class_name ClawMachine
extends Node3D
## 인형뽑기 기계 한 대. 캐비닛·유리·레일(갠트리)·집게·배출구·지폐투입기·조이스틱을 만들고,
## 실제 기계처럼 [지폐 투입 → 시간 내 이동 → 하강 → 집기 → 상승(정상에서 힘 빠짐) → 배출구로 이동 → 놓기] 를 진행한다.

signal state_changed(state: int)
signal prize_won(prize: Prize)
signal credits_changed(credits: int)

enum State { IDLE, MOVING, OPENING, DESCENDING, GRABBING, LIFTING, TOP_HOLD, RETURNING, RELEASING, RESETTING }

const LAYER_ENV := 1
const LAYER_PRIZE := 2
const LAYER_CLAW := 4
const LAYER_INTERACT := 16

@export var machine_id := "big_1"
@export_enum("big", "small") var kind := "big"
@export var theme_color := Color(1.0, 0.45, 0.66)
@export var initial_fill := 14
## 처음 설치할 때의 기본 세팅(이름, 상품 구성, 집게 발 개수 등) – 저장된 설정이 있으면 무시
@export var preset := {}

var settings: Dictionary
var ledger: Dictionary

# 치수(기계 로컬 좌표, 원점 = 바닥 중앙, +Z = 앞)
var W := 1.0
var D := 0.95
var base_h := 0.78
var glass_top := 1.86
var header_h := 0.3
var ix := 0.45
var z_back := -0.42
var z_front := 0.40
var chute_x := -0.17
var chute_z := 0.12
var guard_h := 0.12
var rest_y := 1.56
var rail_y := 1.8
var claw_size := 1.0
var claw_style := "standard"
var joystick_base: Node3D
var btn_labels: Array[Label3D] = []
var bin_y := 0.1
var open_h := 0.3  ## 배출구 구멍 높이
var _bin_scan := 0

var claw: ClawRig
var prizes_root: Node3D
var bin_area: Area3D
var front_cam: Marker3D
var side_cam: Marker3D
var side_cam_l: Marker3D
var close_cam: Marker3D
var interact_body: StaticBody3D
var carriage_mesh: Node3D
var crossbar_mesh: Node3D
var joystick_pivot: Node3D
var button_mesh: MeshInstance3D
var button_mat: StandardMaterial3D
var button2_mesh: MeshInstance3D
var credit_label: Label3D
var timer_label: Label3D
var price_label: Label3D
var name_label: Label3D
var bulbs: Array[MeshInstance3D] = []
var bulb_on: StandardMaterial3D
var bulb_off: StandardMaterial3D
var bill_led: StandardMaterial3D
var motor_player: AudioStreamPlayer3D
var winch_player: AudioStreamPlayer3D
var interior_light: SpotLight3D

# 진행 상태
var state := State.IDLE
var credits := 0
var time_left := 0.0
var carriage := Vector3.ZERO  # 캐리지(줄이 매달린 점)의 로컬 x,z / 헤드 높이는 head_y
var carriage_vel := Vector3.ZERO
var head_y := 1.56
var input_dir := Vector2.ZERO
var drop_requested := false
var strong := false
var phase_t := 0.0
var touch_frames := 0
var sink_left := 0.0
var sway := Vector2.ZERO
var sway_v := Vector2.ZERO
var prev_carriage_vel := Vector3.ZERO
var btn1_used := false
var btn2_used := false
var btn1_down := false
var btn2_down := false
var game_active := false
var _bulb_t := 0.0
var _beep_last := -1
var _settle_frames := 0
var player_present := false


func _ready() -> void:
	settings = Game.get_settings(machine_id, kind, preset)
	ledger = Game.get_ledger(machine_id)
	_setup_dims()
	_build_cabinet()
	_build_gantry()
	_build_controls()
	_build_claw()
	_build_chute()
	_build_cameras()
	prizes_root = Node3D.new()
	prizes_root.name = "Prizes"
	add_child(prizes_root)
	motor_player = Sfx.make_loop_player(self, "motor_loop", -14.0)
	motor_player.position = Vector3(0, rail_y, 0)
	winch_player = Sfx.make_loop_player(self, "winch_loop", -16.0)
	winch_player.position = Vector3(0, rail_y, 0)
	Game.settings_changed.connect(_on_settings_changed)
	carriage = _home()
	head_y = rest_y
	_rest_claw()
	_place_claw_now()
	_update_labels()
	call_deferred("_initial_prizes")


func _setup_dims() -> void:
	if kind == "small":
		W = 0.72
		D = 0.68
		base_h = 0.84
		glass_top = 1.62
		header_h = 0.24
		ix = 0.32
		z_back = -0.29
		z_front = 0.28
		chute_x = -0.12
		chute_z = 0.08
		guard_h = 0.075
		claw_size = 0.62
		rest_y = glass_top - 0.2
		bin_y = 0.12
		open_h = 0.22
	else:
		rest_y = glass_top - 0.3
	rail_y = glass_top - 0.05


func _home() -> Vector3:
	return Vector3((-ix + chute_x) * 0.5, 0, (chute_z + z_front) * 0.5)


# =================================================================== 빌드: 캐비닛
func _mat(color: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node3D = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER_ENV
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		(parent if parent else self).add_child(sb)
	return mi


func _wall(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	## 보이지 않는 충돌벽
	var sb := StaticBody3D.new()
	sb.collision_layer = LAYER_ENV
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation = rot
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	sb.physics_material_override = pm
	add_child(sb)


## 캐비닛 겉면 도장(일본식 기계는 흰색으로 바꾼다)
func _cabinet_paint() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = theme_color
	paint.roughness = 0.28
	paint.metallic = 0.15
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.8
	return paint


func _header_tex_path() -> String:
	return "res://assets/textures/machine/header_neutral.png"  # 테마색으로 물들인다


func _panel_tex_path() -> String:
	return "res://assets/textures/machine/panel_%s.png" % ("big" if kind != "small" else "small")


func _use_bulbs() -> bool:
	return false  # 요즘 뽑기방처럼 전구 대신 LED 네온 띠


## 네온 띠 색: 캐비닛 색과 어울리는 밝은 보색 계열
func neon_color() -> Color:
	var h := fmod(theme_color.h + 0.08, 1.0)
	return Color.from_hsv(h, 0.55, 1.0)


var neon_mat: StandardMaterial3D


func _build_neon(hw: float, hd: float, gh: float) -> void:
	neon_mat = StandardMaterial3D.new()
	var nc := neon_color()
	neon_mat.albedo_color = nc
	neon_mat.emission_enabled = true
	neon_mat.emission = nc
	neon_mat.emission_energy_multiplier = 3.0
	var z := hd + 0.006
	# 유리 창 둘레(앞 기둥 두 개 + 위·아래)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.012, gh, 0.008), Vector3(sx * (hw - 0.0225), base_h + gh * 0.5, z), neon_mat)
	_box(Vector3(W - 0.03, 0.012, 0.008), Vector3(0, glass_top - 0.004, z), neon_mat)
	_box(Vector3(W - 0.03, 0.012, 0.008), Vector3(0, base_h + 0.006, z), neon_mat)
	# 간판 테두리
	_box(Vector3(W + 0.01, 0.012, 0.008), Vector3(0, glass_top + header_h - 0.006, hd + 0.01), neon_mat)
	_box(Vector3(W + 0.01, 0.012, 0.008), Vector3(0, glass_top + 0.008, hd + 0.01), neon_mat)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.012, header_h, 0.008), Vector3(sx * (hw + 0.002), glass_top + header_h * 0.5, hd + 0.01), neon_mat)
	# 아래 받침 둘레(바닥에 비치는 빛)
	_box(Vector3(W + 0.03, 0.014, 0.01), Vector3(0, 0.055, hd + 0.016), neon_mat)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.01, 0.014, D + 0.02), Vector3(sx * (hw + 0.016), 0.055, 0), neon_mat)


## 유리 안쪽 뒷면(인쇄 그림판)
func _build_backdrop(gh: float, white: Material) -> void:
	var back := StandardMaterial3D.new()
	back.albedo_texture = load("res://assets/textures/machine/back_%s.png" % ("big" if kind != "small" else "small"))
	back.roughness = 0.45
	var bq := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(ix * 2.0, gh)
	bq.mesh = qm
	bq.material_override = back
	bq.position = Vector3(0, base_h + gh * 0.5, z_back - 0.001)
	add_child(bq)
	# 뒷판은 네 모서리 기둥 사이에 끼운다(기둥 뒷면과 같은 면이 겹쳐 깜빡이는 것 방지)
	_box(Vector3(W - 0.092, gh, 0.02), Vector3(0, base_h + gh * 0.5, -D * 0.5 + 0.012), white)


func _build_cabinet() -> void:
	var paint := _cabinet_paint()
	# 아래 캐비닛 앞판도 파스텔 테마색(사진 속 분홍·보라 기계처럼)
	var white := _mat(theme_color.lerp(Color(1, 1, 1), 0.55), 0.25)
	white.clearcoat_enabled = true
	var chrome := _mat(Color(0.9, 0.9, 0.92), 0.15, 1.0)
	var dark := _mat(Color(0.08, 0.08, 0.1), 0.6)
	var inner_dark := _mat(Color(0.12, 0.1, 0.16), 0.8)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.92, 1.0, 0.06)
	glass.roughness = 0.02
	glass.metallic_specular = 0.6
	glass.metallic = 0.0
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var hw := W * 0.5
	var hd := D * 0.5
	var t := 0.03
	var tex_tag := "big" if kind != "small" else "small"

	# 아래 캐비닛(배출구 구멍이 있는 앞판은 조각으로)
	# 옆판이 앞뒤 끝까지, 앞판·뒷판은 옆판 사이에 끼운다(같은 면이 겹쳐 테두리가 깜빡이는 것 방지)
	_box(Vector3(t, base_h, D), Vector3(-hw + t * 0.5, base_h * 0.5, 0), paint)
	_box(Vector3(t, base_h, D), Vector3(hw - t * 0.5, base_h * 0.5, 0), paint)
	var iw := hw - t  # 안쪽 반너비
	_box(Vector3(iw * 2.0, base_h, t), Vector3(0, base_h * 0.5, -hd + t * 0.5 + 0.002), paint)
	var open_x0 := -ix
	var open_x1 := chute_x
	var open_y0 := bin_y
	var open_y1 := bin_y + open_h
	var fz := hd - t * 0.5 - 0.002
	# 앞판: 구멍 오른쪽, 구멍 위, 구멍 아래, 구멍 왼쪽
	_box(Vector3(iw - open_x1, base_h, t), Vector3((open_x1 + iw) * 0.5, base_h * 0.5, fz), white)
	_box(Vector3(open_x1 + iw, base_h - open_y1, t), Vector3((-iw + open_x1) * 0.5, (open_y1 + base_h) * 0.5, fz), white)
	_box(Vector3(open_x1 + iw, open_y0, t), Vector3((-iw + open_x1) * 0.5, open_y0 * 0.5, fz), white)
	if open_x0 > -iw + 0.001:
		_box(Vector3(open_x0 + iw, open_y1 - open_y0, t), Vector3((-iw + open_x0) * 0.5, (open_y0 + open_y1) * 0.5, fz), white)
	# 앞판 장식 띠
	_box(Vector3(W + 0.008, 0.05, 0.012), Vector3(0, base_h - 0.06, hd + 0.004), paint)
	_box(Vector3(W + 0.008, 0.025, 0.012), Vector3(0, 0.06, hd + 0.004), paint)
	# 받침(다리)
	_box(Vector3(W + 0.02, 0.046, D + 0.02), Vector3(0, 0.023, 0), dark)
	# 배출구 투명 덮개(아래로 젖혀지는 플랩 느낌)
	var flap := StandardMaterial3D.new()
	flap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flap.albedo_color = Color(0.2, 0.2, 0.25, 0.35)
	flap.roughness = 0.05
	flap.metallic_specular = 1.0
	_box(Vector3(open_x1 - open_x0 - 0.01, open_y1 - open_y0 - 0.06, 0.005), Vector3((open_x0 + open_x1) * 0.5, open_y1 - (open_y1 - open_y0 - 0.06) * 0.5 - 0.005, hd + 0.03), flap, false, null, Vector3(-0.35, 0, 0))
	var take := Label3D.new()
	take.text = "상품 꺼내는 곳 ▼"
	take.font_size = 34
	take.pixel_size = 0.0011 * (1.0 if kind != "small" else 0.8)
	take.outline_size = 8
	take.modulate = Color(1, 1, 1)
	take.position = Vector3((open_x0 + open_x1) * 0.5, open_y1 + 0.03, hd + 0.004)
	add_child(take)

	# 유리 상자 + 기둥
	var gh := glass_top - base_h
	_box(Vector3(W - 0.06, gh, 0.006), Vector3(0, base_h + gh * 0.5, hd - 0.02), glass)
	_box(Vector3(0.006, gh, D - 0.06), Vector3(-hw + 0.02, base_h + gh * 0.5, 0), glass)
	_box(Vector3(0.006, gh, D - 0.06), Vector3(hw - 0.02, base_h + gh * 0.5, 0), glass)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.045, gh, 0.045), Vector3(sx * (hw - 0.0225), base_h + gh * 0.5, sz * (hd - 0.0225)), chrome)
	# 내부 충돌벽(유리 안쪽 면)
	_wall(Vector3(W, gh + 0.2, 0.04), Vector3(0, base_h + gh * 0.5, z_front + 0.02))
	_wall(Vector3(W, gh + 0.2, 0.04), Vector3(0, base_h + gh * 0.5, z_back - 0.02))
	_wall(Vector3(0.04, gh + 0.2, D), Vector3(-ix - 0.02, base_h + gh * 0.5, 0))
	_wall(Vector3(0.04, gh + 0.2, D), Vector3(ix + 0.02, base_h + gh * 0.5, 0))
	_wall(Vector3(W, 0.04, D), Vector3(0, glass_top + 0.02, 0))

	# 뒷판(인쇄 그림)
	_build_backdrop(gh, white)

	_build_bed()

	# 위 간판(헤더)
	var header_mat := StandardMaterial3D.new()
	header_mat.albedo_texture = load(_header_tex_path())
	if _header_tex_path().ends_with("header_neutral.png"):
		header_mat.albedo_color = theme_color.lerp(Color(1, 1, 1), 0.15)
	header_mat.emission_enabled = true
	header_mat.emission_texture = header_mat.albedo_texture
	header_mat.emission_energy_multiplier = 0.6
	header_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	header_mat.emission = header_mat.albedo_color
	_box(Vector3(W, header_h, D), Vector3(0, glass_top + header_h * 0.5, 0), paint)
	var hq := MeshInstance3D.new()
	var hqm := QuadMesh.new()
	hqm.size = Vector2(W - 0.02, header_h - 0.02)
	hq.mesh = hqm
	hq.material_override = header_mat
	hq.position = Vector3(0, glass_top + header_h * 0.5, hd + 0.004)
	add_child(hq)
	name_label = Label3D.new()
	name_label.font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	name_label.font_size = 96
	name_label.pixel_size = 0.0012 * (1.0 if kind != "small" else 0.75)
	name_label.outline_size = 22
	name_label.outline_modulate = Color(0.35, 0.1, 0.25)
	name_label.modulate = Color(1, 1, 0.92)
	name_label.position = Vector3(0, glass_top + header_h * 0.5, hd + 0.009)
	add_child(name_label)
	# 반짝이는 전구 테두리
	bulb_on = _mat(Color(1, 0.95, 0.7), 0.3)
	bulb_on.emission_enabled = true
	bulb_on.emission = Color(1, 0.85, 0.4)
	bulb_on.emission_energy_multiplier = 3.0
	bulb_off = _mat(Color(0.8, 0.75, 0.6), 0.3)
	bulb_off.emission_enabled = true
	bulb_off.emission = Color(1, 0.8, 0.4)
	bulb_off.emission_energy_multiplier = 0.25
	var n := int(W / 0.07) if _use_bulbs() else -1
	for i in n + 1:
		for row in [glass_top + 0.03, glass_top + header_h - 0.03]:
			var b := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.011
			sm.height = 0.022
			sm.radial_segments = 8
			sm.rings = 4
			b.mesh = sm
			b.position = Vector3(-hw + 0.035 + i * (W - 0.07) / n, row, hd + 0.012)
			b.material_override = bulb_on
			add_child(b)
			bulbs.append(b)

	_build_neon(hw, hd, gh)

	# 내부 조명 (LED 바 + 스포트라이트)
	var led := _mat(Color(1, 1, 1), 0.2)
	led.emission_enabled = true
	led.emission = Color(1.0, 0.97, 0.92)
	led.emission_energy_multiplier = 4.0
	_box(Vector3(ix * 1.8, 0.012, 0.02), Vector3(0, glass_top - 0.012, z_front - 0.02), led)
	_box(Vector3(ix * 1.8, 0.012, 0.02), Vector3(0, glass_top - 0.012, z_back + 0.03), led)
	interior_light = SpotLight3D.new()
	interior_light.position = Vector3(0, glass_top - 0.03, 0.05)
	interior_light.rotation = Vector3(-PI / 2, 0, 0)
	interior_light.spot_angle = 62
	interior_light.spot_range = 2.0
	interior_light.light_energy = 2.2 if kind != "small" else 1.6
	interior_light.light_color = Color(1.0, 0.97, 0.93)
	interior_light.shadow_enabled = true
	interior_light.shadow_bias = 0.04
	interior_light.shadow_normal_bias = 1.5
	# 멀리 있는 기계의 그림자·조명은 서서히 끈다(그림자 지도 부족으로 생기는 깜빡임 방지)
	interior_light.distance_fade_enabled = true
	interior_light.distance_fade_begin = 7.0
	interior_light.distance_fade_shadow = 3.5
	interior_light.distance_fade_length = 2.0
	add_child(interior_light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, base_h + (glass_top - base_h) * 0.55, z_front - 0.08)
	fill.omni_range = 0.9
	fill.light_energy = 0.5
	fill.light_color = Color(1.0, 0.9, 0.95)
	fill.distance_fade_enabled = true
	fill.distance_fade_begin = 6.0
	fill.distance_fade_length = 2.0
	add_child(fill)

	# 플레이어 상호작용용 몸체(기계 전체 덩어리)
	interact_body = StaticBody3D.new()
	interact_body.collision_layer = LAYER_INTERACT
	interact_body.collision_mask = 0
	var ics := CollisionShape3D.new()
	var ibs := BoxShape3D.new()
	ibs.size = Vector3(W, glass_top + header_h, D)
	ics.shape = ibs
	ics.position = Vector3(0, (glass_top + header_h) * 0.5, 0)
	interact_body.add_child(ics)
	interact_body.set_meta("interactable", self)
	add_child(interact_body)
	# 플레이어는 상품과 부딪히지 않도록 별도 레이어(8)로 막는다
	var pb := StaticBody3D.new()
	pb.collision_layer = 8
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = Vector3(W + 0.02, glass_top + header_h, D + 0.3)
	pcs.shape = pbs
	pcs.position = Vector3(0, (glass_top + header_h) * 0.5, 0.1)
	pb.add_child(pcs)
	add_child(pb)


func _build_bed() -> void:
	# 상품 바닥(배출구 구멍 제외) – 펠트 원단
	var bed := StandardMaterial3D.new()
	bed.albedo_texture = load("res://assets/textures/machine/prize_bed.png")
	bed.uv1_scale = Vector3(3, 3, 3)
	bed.roughness = 0.95
	var bed_pm := PhysicsMaterial.new()
	bed_pm.friction = 0.8
	var bt := 0.04
	var parts := [
		[Vector3(ix * 2.0, bt, chute_z - z_back), Vector3(0, base_h - bt * 0.5, (z_back + chute_z) * 0.5)],
		[Vector3(ix - chute_x, bt, z_front - chute_z), Vector3((chute_x + ix) * 0.5, base_h - bt * 0.5, (chute_z + z_front) * 0.5)],
	]
	for p in parts:
		var mi := _box(p[0], p[1], bed, false)
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER_ENV
		sb.physics_material_override = bed_pm
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = p[0]
		cs.shape = bs
		sb.add_child(cs)
		sb.position = p[1]
		add_child(sb)
		mi.name = "Bed"


# =================================================================== 빌드: 레일
func _build_gantry() -> void:
	var metal := _mat(Color(0.75, 0.76, 0.8), 0.3, 0.9)
	var black := _mat(Color(0.1, 0.1, 0.12), 0.5, 0.3)
	_box(Vector3(0.03, 0.03, z_front - z_back), Vector3(-ix + 0.015, rail_y, (z_front + z_back) * 0.5), metal)
	_box(Vector3(0.03, 0.03, z_front - z_back), Vector3(ix - 0.015, rail_y, (z_front + z_back) * 0.5), metal)
	crossbar_mesh = Node3D.new()
	add_child(crossbar_mesh)
	_box(Vector3(ix * 2.0, 0.025, 0.04), Vector3.ZERO, metal, false, crossbar_mesh)
	carriage_mesh = Node3D.new()
	add_child(carriage_mesh)
	_box(Vector3(0.09 * claw_size + 0.02, 0.05, 0.09), Vector3(0, -0.02, 0), black, false, carriage_mesh)
	_box(Vector3(0.05, 0.03, 0.05), Vector3(0, -0.055, 0), metal, false, carriage_mesh)


# =================================================================== 빌드: 조작부
func _build_controls() -> void:
	var hw := W * 0.5
	var hd := D * 0.5
	var tex_tag := "big" if kind != "small" else "small"
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_texture = load(_panel_tex_path())
	panel_mat.roughness = 0.35
	var panel_root := Node3D.new()
	panel_root.position = Vector3(0, base_h - 0.03, hd + 0.11)
	panel_root.rotation.x = deg_to_rad(10)
	add_child(panel_root)
	_box(Vector3(W - 0.04, 0.06, 0.22), Vector3.ZERO, panel_mat, true, panel_root)
	_box(Vector3(W - 0.036, 0.012, 0.226), Vector3(0, 0.036, 0), _mat(Color(0.62, 0.63, 0.66), 0.3, 0.85), false, panel_root)
	# 조이스틱
	var js_x := -0.22 if kind != "small" else -0.15
	var base_ring := MeshInstance3D.new()
	var brm := CylinderMesh.new()
	brm.top_radius = 0.035
	brm.bottom_radius = 0.04
	brm.height = 0.012
	base_ring.mesh = brm
	base_ring.material_override = _mat(Color(0.1, 0.1, 0.12), 0.4)
	base_ring.position = Vector3(js_x, 0.045, 0)
	panel_root.add_child(base_ring)
	joystick_base = base_ring
	joystick_pivot = Node3D.new()
	joystick_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # 매 프레임(_process)에 움직인다
	joystick_pivot.position = Vector3(js_x, 0.045, 0)
	panel_root.add_child(joystick_pivot)
	var shaft := MeshInstance3D.new()
	var shm := CylinderMesh.new()
	shm.top_radius = 0.007
	shm.bottom_radius = 0.008
	shm.height = 0.09
	shaft.mesh = shm
	shaft.position.y = 0.045
	shaft.material_override = _mat(Color(0.8, 0.8, 0.82), 0.2, 1.0)
	joystick_pivot.add_child(shaft)
	var ball := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.024
	bm.height = 0.048
	ball.mesh = bm
	ball.position.y = 0.095
	var ball_mat := _mat(Color(0.95, 0.15, 0.2), 0.2)
	ball_mat.clearcoat_enabled = true
	ball.material_override = ball_mat
	joystick_pivot.add_child(ball)
	var boot := MeshInstance3D.new()
	var bom := CylinderMesh.new()
	bom.top_radius = 0.012
	bom.bottom_radius = 0.03
	bom.height = 0.02
	boot.mesh = bom
	boot.position.y = 0.01
	boot.material_override = _mat(Color(0.05, 0.05, 0.06), 0.8)
	joystick_pivot.add_child(boot)
	# 버튼(하강) + 2버튼 모드용 버튼
	button_mat = _mat(Color(1.0, 0.25, 0.3), 0.25)
	button_mat.emission_enabled = true
	button_mat.emission = Color(1.0, 0.2, 0.25)
	button_mat.emission_energy_multiplier = 0.5
	button_mesh = _make_button(panel_root, Vector3(0.2 if kind != "small" else 0.14, 0.04, 0.0), button_mat, 0.032)
	var b2mat := _mat(Color(0.2, 0.55, 1.0), 0.25)
	b2mat.emission_enabled = true
	b2mat.emission = Color(0.2, 0.5, 1.0)
	b2mat.emission_energy_multiplier = 0.4
	button2_mesh = _make_button(panel_root, Vector3(0.06 if kind != "small" else 0.03, 0.04, 0.02), b2mat, 0.024)
	# 2버튼 모드용 버튼 표시(① → / ② ↑)
	for i in 2:
		var bl3 := Label3D.new()
		bl3.text = "① →" if i == 0 else "② ↑"
		bl3.font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
		bl3.font_size = 40
		bl3.pixel_size = 0.0011
		bl3.outline_size = 10
		bl3.outline_modulate = Color(0.05, 0.05, 0.1)
		bl3.rotation.x = -PI / 2
		var bpos: Vector3 = (button2_mesh if i == 0 else button_mesh).position
		bl3.position = bpos + Vector3(0, 0.015, 0.06)
		panel_root.add_child(bl3)
		btn_labels.append(bl3)
	_refresh_control_look()
	# LED 표시창(크레딧/시간) – 조작판 위에 비스듬히 세워 플레이 중에 잘 보이게
	var disp := _mat(Color(0.03, 0.03, 0.04), 0.3)
	var disp_root := Node3D.new()
	var dw := 0.2 if kind != "small" else 0.15
	disp_root.position = Vector3(-0.07 if kind != "small" else -0.055, 0.085, -0.055)
	disp_root.rotation.x = deg_to_rad(-40)
	panel_root.add_child(disp_root)
	_box(Vector3(dw + 0.02, 0.095, 0.03), Vector3(0, 0, -0.006), _mat(Color(0.85, 0.86, 0.9), 0.25, 0.8), false, disp_root)
	_box(Vector3(dw, 0.08, 0.02), Vector3(0, 0, 0.004), disp, false, disp_root)
	_box(Vector3(0.03, 0.05, 0.03), Vector3(0, -0.06, -0.01), _mat(Color(0.2, 0.2, 0.22), 0.4), false, disp_root)
	var seg := load("res://assets/fonts/DoHyeon-Regular.ttf")
	credit_label = Label3D.new()
	credit_label.font = seg
	credit_label.font_size = 40
	credit_label.pixel_size = 0.00095 if kind != "small" else 0.0008
	credit_label.modulate = Color(1.0, 0.3, 0.25)
	credit_label.position = Vector3(0, 0.018, 0.016)
	credit_label.shaded = false
	credit_label.outline_size = 0
	disp_root.add_child(credit_label)
	timer_label = Label3D.new()
	timer_label.font = seg
	timer_label.font_size = 40
	timer_label.pixel_size = 0.00095 if kind != "small" else 0.0008
	timer_label.modulate = Color(0.3, 1.0, 0.45)
	timer_label.position = Vector3(0, -0.02, 0.016)
	timer_label.shaded = false
	timer_label.outline_size = 0
	disp_root.add_child(timer_label)
	# 가격표 스티커(앞 유리 아래쪽)
	price_label = Label3D.new()
	price_label.font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	price_label.font_size = 52
	price_label.pixel_size = 0.0011 * (1.0 if kind != "small" else 0.8)
	price_label.outline_size = 14
	price_label.outline_modulate = Color(0.3, 0.05, 0.15)
	price_label.modulate = Color(1, 0.95, 0.3)
	price_label.position = Vector3(ix - (0.17 if kind != "small" else 0.12), glass_top - (0.13 if kind != "small" else 0.1), hd - 0.012)
	add_child(price_label)
	# 지폐 투입구
	var acc_root := Node3D.new()
	acc_root.position = Vector3(hw - (0.17 if kind != "small" else 0.13), base_h - 0.3, hd + 0.003)
	add_child(acc_root)
	_box(Vector3(0.13, 0.16, 0.02), Vector3.ZERO, _mat(Color(0.12, 0.12, 0.14), 0.4, 0.4), false, acc_root)
	_box(Vector3(0.1, 0.006, 0.022), Vector3(0, 0.03, 0.002), _mat(Color(0.0, 0.0, 0.0), 0.9), false, acc_root)
	bill_led = _mat(Color(0.2, 1.0, 0.3), 0.3)
	bill_led.emission_enabled = true
	bill_led.emission = Color(0.2, 1.0, 0.3)
	bill_led.emission_energy_multiplier = 2.0
	_box(Vector3(0.1, 0.004, 0.022), Vector3(0, 0.022, 0.002), bill_led, false, acc_root)
	var bl := Label3D.new()
	bl.text = "지폐 넣는 곳\n1,000원" + (" / 5,000원" if settings.get("accept_5000", true) else "")
	bl.font_size = 22
	bl.pixel_size = 0.0011
	bl.outline_size = 6
	bl.position = Vector3(0, -0.035, 0.012)
	acc_root.add_child(bl)


## 조작 방식에 맞게 패널 모양을 바꾼다: 2버튼이면 조이스틱을 숨기고 ①/② 표시
func _refresh_control_look() -> void:
	var two := String(settings.get("control_mode", "joystick")) == "2button"
	if joystick_pivot:
		joystick_pivot.visible = not two
	if joystick_base:
		joystick_base.visible = not two
	for l in btn_labels:
		l.visible = two


func _make_button(parent: Node3D, pos: Vector3, mat: Material, r: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = r + 0.007
	rm.bottom_radius = r + 0.009
	rm.height = 0.012
	ring.mesh = rm
	ring.material_override = _mat(Color(0.9, 0.9, 0.92), 0.2, 0.9)
	ring.position = pos
	parent.add_child(ring)
	var b := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.018
	b.mesh = cm
	b.material_override = mat
	b.position = pos + Vector3(0, 0.01, 0)
	parent.add_child(b)
	return b


# =================================================================== 빌드: 집게
func _build_claw() -> void:
	if claw:
		claw.queue_free()
	claw = ClawRig.new()
	claw.name = "Claw"
	claw.size = claw_size
	claw.style = claw_style
	claw.prong_count = int(settings.get("prong_count", 3))
	claw.open_angle = deg_to_rad(float(settings.get("open_angle", 42)))
	claw.position = Vector3(_home().x, rest_y, _home().z)
	add_child(claw)


## 평소 자세: 집게는 펼쳐 둔다
func _rest_claw() -> void:
	claw.open()


func _rebuild_claw() -> void:
	## 발 개수/벌림 각도를 바꾸면 집게를 새로 단다(사장 모드)
	var old := claw
	claw = null
	if old:
		old.free()
	carriage = _home()
	head_y = rest_y
	sway = Vector2.ZERO
	sway_v = Vector2.ZERO
	_build_claw()
	_rest_claw()
	_place_claw_now()


# =================================================================== 빌드: 배출구
func _build_chute() -> void:
	var inner := _mat(Color(0.14, 0.12, 0.18), 0.85)
	var acrylic := StandardMaterial3D.new()
	acrylic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	acrylic.albedo_color = Color(0.9, 0.95, 1.0, 0.18)
	acrylic.roughness = 0.03
	acrylic.metallic_specular = 1.0
	acrylic.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cw := chute_x - (-ix)
	var cd := z_front - chute_z
	# 투명 가림막(배출구 둘레)
	_box(Vector3(0.006, guard_h, cd), Vector3(chute_x, base_h + guard_h * 0.5, (chute_z + z_front) * 0.5), acrylic, true)
	_box(Vector3(cw + 0.006, guard_h, 0.006), Vector3((-ix + chute_x) * 0.5, base_h + guard_h * 0.5, chute_z), acrylic, true)
	var trim := _mat(Color(1, 1, 1), 0.3)
	trim.emission_enabled = true
	trim.emission = theme_color
	trim.emission_energy_multiplier = 1.2
	_box(Vector3(0.01, 0.01, cd), Vector3(chute_x, base_h + guard_h, (chute_z + z_front) * 0.5), trim)
	_box(Vector3(cw, 0.01, 0.01), Vector3((-ix + chute_x) * 0.5, base_h + guard_h, chute_z), trim)
	# 배출 통로(세로 통) – 안쪽 벽
	var shaft_h := base_h - bin_y
	_box(Vector3(0.01, shaft_h, cd), Vector3(chute_x + 0.005, bin_y + shaft_h * 0.5, (chute_z + z_front) * 0.5), inner, true)
	_box(Vector3(cw, shaft_h, 0.01), Vector3((-ix + chute_x) * 0.5, bin_y + shaft_h * 0.5, chute_z - 0.005), inner, true)
	_box(Vector3(0.01, shaft_h, cd), Vector3(-ix - 0.005, bin_y + shaft_h * 0.5, (chute_z + z_front) * 0.5), inner, true)
	# 배출구 위쪽 앞면(유리 아래 ~ 구멍 위) 안쪽 충돌벽
	var open_y1 := bin_y + open_h
	_wall(Vector3(cw, base_h - open_y1, 0.02), Vector3((-ix + chute_x) * 0.5, (open_y1 + base_h) * 0.5, z_front + 0.03))
	# 바닥: 앞으로 살짝 기울어진 받침 + 앞쪽 턱
	_box(Vector3(cw, 0.02, cd + 0.06), Vector3((-ix + chute_x) * 0.5, bin_y - 0.01, (chute_z + z_front) * 0.5 + 0.03), inner, true, null, Vector3(deg_to_rad(6), 0, 0))
	_wall(Vector3(cw, 0.04, 0.02), Vector3((-ix + chute_x) * 0.5, bin_y + 0.02, D * 0.5 + 0.02))
	# 배출 감지 영역
	bin_area = Area3D.new()
	bin_area.collision_layer = 0
	bin_area.collision_mask = LAYER_PRIZE
	bin_area.monitoring = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(cw, base_h - bin_y - 0.12, cd + 0.05)
	cs.shape = bs
	cs.position = Vector3((-ix + chute_x) * 0.5, bin_y + (base_h - bin_y - 0.12) * 0.5, (chute_z + z_front) * 0.5 + 0.02)
	bin_area.add_child(cs)
	add_child(bin_area)
	bin_area.body_entered.connect(_on_bin_body)
	# 배출구 안 조명
	var bl := OmniLight3D.new()
	bl.position = Vector3((-ix + chute_x) * 0.5, bin_y + 0.18, z_front)
	bl.omni_range = 0.4
	bl.light_energy = 0.6
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 5.0
	bl.distance_fade_length = 1.5
	add_child(bl)


func _build_cameras() -> void:
	var mid_y := base_h + (glass_top - base_h) * 0.42
	front_cam = Marker3D.new()
	add_child(front_cam)
	var eye_h := 1.62 if kind != "small" else 1.5
	var fp := Vector3(0.0, eye_h, D * 0.5 + (0.95 if kind != "small" else 0.72))
	front_cam.transform = Transform3D(Basis.looking_at(Vector3(0, mid_y - 0.08, -0.02) - fp), fp)
	side_cam = Marker3D.new()
	add_child(side_cam)
	# 옆 기계에 가리지 않도록 앞쪽 모서리에서 비스듬히 들여다보는 시점
	var sp := Vector3(W * 0.5 + (0.25 if kind != "small" else 0.18), eye_h - 0.05, D * 0.5 + (0.62 if kind != "small" else 0.5))
	side_cam.transform = Transform3D(Basis.looking_at(Vector3(0, mid_y - 0.08, 0) - sp), sp)
	side_cam_l = Marker3D.new()
	add_child(side_cam_l)
	var spl := Vector3(-sp.x, sp.y, sp.z)
	side_cam_l.transform = Transform3D(Basis.looking_at(Vector3(0, mid_y - 0.08, 0) - spl), spl)
	close_cam = Marker3D.new()
	add_child(close_cam)
	var cp := Vector3(0.0, base_h + (glass_top - base_h) * 0.55, D * 0.5 + 0.25)
	close_cam.transform = Transform3D(Basis.looking_at(Vector3(0, base_h + 0.08, -0.05) - cp), cp)


# =================================================================== 상품 관리
func _initial_prizes() -> void:
	var saved: Array = Game.machine_prizes.get(machine_id, [])
	if not saved.is_empty():
		var placed := 0
		for st in saved:
			# 예전 저장(가게 좌표)이 지금 기계 안이 아니면(가게 배치가 바뀜) 버린다
			if String(st.get("space", "")) != "local" and not _saved_inside(st):
				continue
			var p := PrizeFactory.create(st["id"], null, int(st.get("colorway", 0)))
			if p == null:
				continue
			prizes_root.add_child(p)
			p.load_state(st, global_transform)
			placed += 1
		if placed > 0:
			if kind != "bridge":
				top_up.call_deferred()
			return
	fill_random(initial_fill)


func _saved_inside(st: Dictionary) -> bool:
	var parts: Array = st.get("parts", [])
	if parts.is_empty():
		return false
	var p: Array = parts[0]
	var l := to_local(Vector3(p[0], p[1], p[2]))
	return absf(l.x) < ix + 0.02 and l.z > z_back - 0.05 and l.z < z_front + 0.05 and l.y > bin_y - 0.05 and l.y < glass_top


func _rand_pos_in_bed(rng: RandomNumberGenerator, margin: float) -> Vector3:
	for k in 30:
		var x := rng.randf_range(-ix + margin, ix - margin)
		var z := rng.randf_range(z_back + margin, z_front - margin)
		if x < chute_x + margin * 1.4 and z > chute_z - margin * 1.4:
			continue
		return Vector3(x, 0, z)
	return Vector3(ix * 0.5, 0, z_back * 0.5)


func fill_random(count: int, ids: Array = []) -> void:
	if ids.is_empty():
		ids = settings.get("prize_ids", PrizeCatalog.ids_for(kind))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# 겹치지 않게 층층이 떨어뜨려 쌓는다(가득 찬 실제 기계처럼)
	var margin := 0.09 if kind != "small" else 0.05
	var min_d := 0.13 if kind != "small" else 0.075
	var placed: Array[Vector3] = []
	var top_y := glass_top - 0.38 if kind != "small" else glass_top - 0.3
	for i in count:
		var id: String = ids[rng.randi() % ids.size()]
		var lp := Vector3.ZERO
		var y := base_h + 0.12
		for tries in 40:
			lp = _rand_pos_in_bed(rng, margin)
			y = base_h + 0.12
			# 같은 높이에 너무 가까운 것이 있으면 한 층 위로
			var ok := false
			while y < top_y:
				ok = true
				for q in placed:
					if absf(q.y - y) < min_d and Vector2(q.x - lp.x, q.z - lp.z).length() < min_d:
						ok = false
						break
				if ok:
					break
				y += min_d * 0.9
			if ok:
				break
		lp.y = minf(y, top_y)
		placed.append(lp)
		add_prize(id, to_global(lp), rng.randf() * TAU, rng)


## 저장된 상품이 기본 개수보다 적으면 위에서 더 떨어뜨려 채운다(처음부터 넉넉하게 차 있는 기계)
func top_up() -> void:
	var n := get_prizes().size()
	if n < int(initial_fill * 0.85):
		fill_random(initial_fill - n)


func add_prize(id: String, global_pos: Vector3, rot_y: float = 0.0, rng: RandomNumberGenerator = null) -> Prize:
	var p := PrizeFactory.create(id, rng)
	if p == null:
		return null
	prizes_root.add_child(p)
	# 엎어지거나 옆으로 누운 자세도 섞는다
	var tilt := Basis()
	if rng != null and rng.randf() < 0.45:
		tilt = Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf_range(0.6, 1.6))
	p.global_transform = Transform3D(global_transform.basis * Basis(Vector3.UP, rot_y) * tilt, global_pos)
	ledger["stocked_cost"] = int(ledger.get("stocked_cost", 0)) + p.cost
	return p


func _return_to_bed(p: Prize) -> void:
	if not is_instance_valid(p):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var lp := _rand_pos_in_bed(rng, 0.12 if kind != "small" else 0.07)
	lp.y = base_h + 0.3
	p.teleport_to(to_global(lp), rng.randf() * TAU)


func remove_prize(p: Prize) -> void:
	if p and is_instance_valid(p):
		p.queue_free()


func clear_prizes() -> void:
	for c in prizes_root.get_children():
		c.queue_free()


func get_prizes() -> Array:
	var out := []
	for c in prizes_root.get_children():
		if c is Prize and not c.is_queued_for_deletion():
			out.append(c)
	return out


func save_layout() -> void:
	var arr := []
	for p in get_prizes():
		if not p.won:
			arr.append(p.save_state(global_transform))
	Game.machine_prizes[machine_id] = arr


## 배출구에 떨어져 있는(꺼낼 수 있는) 상품
func prizes_in_bin() -> Array:
	var out := []
	for p in get_prizes():
		if p.won:
			out.append(p)
	return out


func take_prizes_from_bin() -> Array:
	var taken := []
	for p in prizes_in_bin():
		taken.append({"id": p.prize_id, "colorway": p.colorway})
		Game.add_to_collection(p.prize_id, p.colorway, machine_id)
		p.queue_free()
	if not taken.is_empty():
		Sfx.play_at("chute_thud", to_global(Vector3(-ix * 0.6, 0.3, D * 0.5)))
		save_layout()
	return taken


var _last_game_end := -100000


## 이 높이 아래로 떨어지면 획득
func _win_y() -> float:
	return base_h - 0.05


func _on_bin_body(body: Node3D) -> void:
	var p := body.get_parent()
	if p is Prize and not p.won:
		var c := to_local((p as Prize).get_center())
		# 아무도 플레이하지 않을 때(진열·정리 중) 떨어진 상품은 사장님이 다시 넣어 둔다
		if not game_active and Time.get_ticks_msec() - _last_game_end > 4000:
			_return_to_bed.call_deferred(p)
			return
		if c.y < _win_y():
			p.won = true
			ledger["payouts"] = int(ledger["payouts"]) + 1
			ledger["payout_cost"] = int(ledger["payout_cost"]) + p.cost
			ledger["plays_since_payout"] = 0
			ledger["revenue_since_payout"] = 0
			Sfx.play_at("plush_thud", p.get_center())
			Sfx.play("win", -2.0)
			Game.say("🎉 %s 획득! 배출구에서 꺼내세요 (E)" % p.display_name)
			prize_won.emit(p)
			save_layout()


# =================================================================== 돈/크레딧
func price_text() -> String:
	var per := int(settings["plays_per_1000"])
	var txt := "1회 1,000원" if per == 1 else "1,000원 %d회" % per
	if settings.get("accept_5000", true):
		txt += "\n5,000원 %d회" % int(settings["bonus_5000"])
	return txt


func insert_bill(kind_str: String) -> bool:
	if kind_str == "5000" and not settings.get("accept_5000", true):
		Game.say("이 기계는 5,000원권을 받지 않아요")
		return false
	if not Game.take_bill(kind_str):
		Game.say("%s권이 없어요. 지폐교환기를 이용하세요" % Game.won(int(kind_str)))
		return false
	var plays := int(settings["plays_per_1000"]) if kind_str == "1000" else int(settings["bonus_5000"])
	credits += plays
	ledger["revenue"] = int(ledger["revenue"]) + int(kind_str)
	Game.record_spend(int(kind_str))
	Sfx.play_at("bill_insert", to_global(Vector3(W * 0.3, base_h - 0.3, D * 0.5)))
	get_tree().create_timer(0.9).timeout.connect(func(): Sfx.play_at("credit", global_position + Vector3(0, base_h, 0)))
	credits_changed.emit(credits)
	if state == State.IDLE:
		get_tree().create_timer(1.0).timeout.connect(_start_game)
	_update_labels()
	return true


func _start_game() -> void:
	if state != State.IDLE or credits <= 0:
		return
	credits -= 1
	game_active = true
	ledger["plays"] = int(ledger["plays"]) + 1
	ledger["plays_since_payout"] = int(ledger["plays_since_payout"]) + 1
	var per_play: int = 1000 / maxi(int(settings["plays_per_1000"]), 1)
	ledger["revenue_since_payout"] = int(ledger["revenue_since_payout"]) + per_play
	Game.stats["plays"] = int(Game.stats["plays"]) + 1
	# 확률(강집게) 판정
	match String(settings["payout_mode"]):
		"count":
			strong = int(ledger["plays_since_payout"]) >= int(settings["payout_every"])
		"revenue":
			strong = int(ledger["revenue_since_payout"]) >= int(settings["payout_revenue"])
		_:
			strong = false
	time_left = float(settings["timer_sec"])
	btn1_used = false
	btn2_used = false
	drop_requested = false
	if settings.get("start_from_home", true):
		pass
	_set_state(State.MOVING)
	Sfx.play_at("start", to_global(Vector3(0, base_h, D * 0.5)))
	credits_changed.emit(credits)
	_update_labels()


func _power(key: String) -> float:
	if strong:
		return float(settings["strong_power"]) / 100.0
	return float(settings[key]) / 100.0


# =================================================================== 입력(플레이어가 호출)
func set_input(dir: Vector2) -> void:
	input_dir = dir


func press_drop() -> void:
	if state == State.MOVING:
		if String(settings["control_mode"]) == "2button":
			return
		drop_requested = true
		Sfx.play_at("button", to_global(Vector3(0.2, base_h, D * 0.5 + 0.1)))


## 2버튼 기계: 버튼1(→) / 버튼2(↑ 안쪽) 를 누르고 있는 동안 이동, 떼면 그 방향은 끝
func set_buttons(b1: bool, b2: bool) -> void:
	if String(settings["control_mode"]) != "2button" or state != State.MOVING:
		btn1_down = false
		btn2_down = false
		return
	if btn1_down and not b1:
		btn1_used = true
	if btn2_down and not b2:
		btn2_used = true
		drop_requested = true
	if b1 and not btn1_down and not btn1_used:
		Sfx.play_at("button", to_global(Vector3(0.06, base_h, D * 0.5 + 0.1)))
	if b2 and not btn2_down and not btn2_used:
		btn1_used = true
		Sfx.play_at("button", to_global(Vector3(0.2, base_h, D * 0.5 + 0.1)))
	btn1_down = b1 and not btn1_used
	btn2_down = b2 and not btn2_used and btn1_used


# =================================================================== 진행
func _set_state(s: int) -> void:
	state = s
	if claw:
		claw.limit_load = s == State.LIFTING or s == State.TOP_HOLD or s == State.RETURNING
	phase_t = 0.0
	state_changed.emit(s)


func _physics_process(delta: float) -> void:
	if claw == null:
		return
	phase_t += delta
	var speed := float(settings["move_speed"])
	var want := Vector3.ZERO
	match state:
		State.IDLE:
			pass
		State.MOVING:
			time_left -= delta
			var sec := int(ceil(time_left))
			if sec <= 5 and sec != _beep_last and sec >= 0:
				_beep_last = sec
				Sfx.play_at("beep", to_global(Vector3(0, base_h, D * 0.5)), -6.0)
			if String(settings["control_mode"]) == "2button":
				if btn1_down:
					want.x = 1.0
				elif btn2_down:
					want.z = -1.0
			else:
				want = Vector3(input_dir.x, 0, input_dir.y)
				if want.length() > 1.0:
					want = want.normalized()
			if time_left <= 0.0 and not drop_requested:
				time_left = 0.0
				if settings.get("auto_drop", true) or String(settings["control_mode"]) == "2button":
					drop_requested = true
				Sfx.play_at("timeup", to_global(Vector3(0, base_h, D * 0.5)), -4.0)
			if drop_requested:
				want = Vector3.ZERO
			if drop_requested and carriage_vel.length() < 0.02:
				drop_requested = false
				claw.open()
				Sfx.play_at("claw_open", claw.head.global_position)
				_set_state(State.OPENING)
		State.OPENING:
			if phase_t > 0.35:
				touch_frames = 0
				sink_left = -1.0
				_set_state(State.DESCENDING)
		State.DESCENDING:
			var min_y := base_h + 0.005
			var depth_pct := float(settings.get("drop_depth", 100)) / 100.0
			var lim_y: float = lerp(rest_y, min_y, depth_pct)
			head_y -= float(settings["drop_speed"]) * delta
			if claw.head_blocked(0.006) or _prong_on_floor():
				touch_frames += 1
			elif claw_style == "ufo" and claw.max_flex() > deg_to_rad(16.0):
				# UFO형: 팔 끝이 상자를 누르면 팔이 살짝 꺾이며(스프링) 그 힘만큼만 누른다.
				# 충분히 꺾이면 줄이 느슨해진 것으로 보고 멈춘다 → 상자를 날리지 않고 '살짝' 누름
				touch_frames += 1
			var done := head_y <= lim_y
			# 빠르게 내려올수록 닿자마자 멈춘다(한 틱에 내려가는 거리가 커서)
			if touch_frames >= (3 if float(settings["drop_speed"]) < 0.25 else 1):
				# 줄이 느슨해지면서 1cm 정도 더 내려앉은 뒤 멈춘다
				if sink_left < 0.0:
					sink_left = (0.003 if claw_style == "ufo" else 0.01) * claw_size
				sink_left -= float(settings["drop_speed"]) * delta
				if sink_left <= 0.0:
					done = true
			if done:
				head_y = max(head_y, lim_y)
				claw.close(_power("power_grab"))
				Sfx.play_at("claw_close", claw.head.global_position)
				_set_state(State.GRABBING)
		State.GRABBING:
			# UFO형: 줄이 느슨해진 집게의 무게(약 0.6kg)만큼 닿은 상자를 살짝 누른다(날려 보내지 않음)
			if claw_style == "ufo" and phase_t < 0.6:
				claw.press_touching(6.0)
			if phase_t > 0.75:
				claw.set_power(_power("power_lift"))
				_remember_grabbed()
				_set_state(State.LIFTING)
		State.LIFTING:
			_check_slip()
			head_y += float(settings["lift_speed"]) * delta
			if head_y >= rest_y:
				head_y = rest_y
				_set_state(State.TOP_HOLD)
		State.TOP_HOLD:
			_check_slip()
			# 정상에 도착하면 일정 시간 뒤 힘이 빠진다(일명 '정상 드롭')
			if phase_t >= float(settings["top_drop_delay"]) and claw.power != _power("power_top"):
				claw.set_power(_power("power_top"))
			if phase_t >= float(settings["top_drop_delay"]) + 0.35:
				claw.set_power(_power("power_carry"))
				_set_state(State.RETURNING)
		State.RETURNING:
			var h := _home()
			var d := Vector3(h.x - carriage.x, 0, h.z - carriage.z)
			if d.length() < 0.006 and carriage_vel.length() < 0.02:
				carriage.x = h.x
				carriage.z = h.z
				carriage_vel = Vector3.ZERO
				claw.open_release()
				Sfx.play_at("claw_open", claw.head.global_position)
				_set_state(State.RELEASING)
			else:
				want = d.normalized() * clamp(d.length() / 0.06, 0.15, 1.0)
		State.RELEASING:
			if phase_t > 1.3:
				_set_state(State.RESETTING)
		State.RESETTING:
			if phase_t > 0.6:
				game_active = false
				_last_game_end = Time.get_ticks_msec()
				_set_state(State.IDLE)
				save_layout()
				if credits > 0:
					get_tree().create_timer(0.6).timeout.connect(_start_game)
	# 배출구 영역에 걸쳐 있는 상품을 주기적으로 다시 확인(천천히 미끄러져 들어가는 경우)
	_bin_scan += 1
	if _bin_scan % 8 == 0 and bin_area:
		for b in bin_area.get_overlapping_bodies():
			_on_bin_body(b)
	_move_carriage(want, speed, delta)
	_update_sway(delta)
	_place_claw_now()
	_update_audio()


## UFO형(일본 기계): 잡은 상품의 처음 높이를 기억해 두고, 몇 cm 이상 들리면 팔이 버티지 못하고 놓친다.
## → 무거운 피규어 상자는 '살짝' 들렸다 미끄러지며 자리만 옮겨진다(통째로 들어 옮기는 일은 없음).
const UFO_MAX_LIFT := 0.035
var _grab_y := {}


func _remember_grabbed() -> void:
	_grab_y.clear()
	if claw_style != "ufo":
		return
	for p in claw.prongs:
		for b in p.get_colliding_bodies():
			if b is RigidBody3D:
				_grab_y[b] = (b as RigidBody3D).global_position.y


func _check_slip() -> void:
	if claw_style != "ufo" or not claw.closing:
		return
	# 들어 올리는 중에 새로 닿은 상품도 그때 높이부터 잰다
	for p in claw.prongs:
		for nb in p.get_colliding_bodies():
			if nb is RigidBody3D and not _grab_y.has(nb):
				_grab_y[nb] = (nb as RigidBody3D).global_position.y
	for b in _grab_y:
		if is_instance_valid(b) and (b as RigidBody3D).global_position.y - float(_grab_y[b]) > UFO_MAX_LIFT:
			_grab_y.clear()
			claw.open()
			Sfx.play_at("claw_open", claw.head.global_position, -6.0)
			return


## 발끝이 바닥(상품 받침)에 닿았는지 – 옆 유리벽에 스치는 것은 무시
func _prong_on_floor() -> bool:
	for tip in claw.tip_positions():
		if to_local(tip).y <= base_h + 0.012:
			return true
	return false


func _move_carriage(want: Vector3, speed: float, delta: float) -> void:
	var target := want * speed
	var acc := maxf(1.4, speed * 5.0)  # 빠른 레일은 가속도 더 크게(실제 모터처럼 금방 최고 속도)
	var dv := target - carriage_vel
	var maxdv := acc * delta
	if dv.length() > maxdv:
		dv = dv.normalized() * maxdv
	prev_carriage_vel = carriage_vel
	carriage_vel += dv
	carriage += carriage_vel * delta
	var m := 0.05 * claw_size + 0.02
	var cx: float = clamp(carriage.x, -ix + m, ix - m)
	var cz: float = clamp(carriage.z, z_back + m, z_front - m)
	if cx != carriage.x:
		carriage_vel.x = 0
	if cz != carriage.z:
		carriage_vel.z = 0
	carriage.x = cx
	carriage.z = cz


func _update_sway(delta: float) -> void:
	var L: float = max(rail_y - 0.06 - (head_y + claw.head_height), 0.05)
	var a: Vector3 = (carriage_vel - prev_carriage_vel) / maxf(delta, 0.0001)
	var k := float(settings.get("sway", 0.5))
	var g := 9.81
	var acc := Vector2(-a.x, -a.z) / L * k
	var damp := maxf(1.6 - k * 0.9, 0.12)  # 흔들림을 아주 크게 해도 감쇠가 0 아래로 가지 않게
	sway_v += (acc - (g / L) * sway - damp * sway_v) * delta
	sway += sway_v * delta
	sway = sway.limit_length(0.5)


func _place_claw_now() -> void:
	var top := Vector3(carriage.x, rail_y - 0.06, carriage.z)
	var L: float = max(top.y - (head_y + claw.head_height), 0.0)
	var off := Vector3(sin(sway.x) * L, 0, sin(sway.y) * L)
	var tilt := Basis(Vector3.BACK, -sway.x) * Basis(Vector3.RIGHT, sway.y)
	var local := Transform3D(tilt, Vector3(carriage.x, head_y, carriage.z) + off)
	var xf := global_transform * local
	claw.move_head(xf, to_global(top))
	crossbar_mesh.position = Vector3(0, rail_y, carriage.z)
	carriage_mesh.position = Vector3(carriage.x, rail_y, carriage.z)


func _update_audio() -> void:
	var moving := carriage_vel.length() > 0.01
	if moving and not motor_player.playing:
		motor_player.play()
	elif not moving and motor_player.playing:
		motor_player.stop()
	var winding := state == State.DESCENDING or state == State.LIFTING
	if winding and not winch_player.playing:
		winch_player.play()
	elif not winding and winch_player.playing:
		winch_player.stop()
	motor_player.position = Vector3(carriage.x, rail_y, carriage.z)


func _process(delta: float) -> void:
	_bulb_t += delta
	var step := int(_bulb_t * (8.0 if game_active else 3.0))
	for i in bulbs.size():
		var on := (i + step) % 3 != 0
		bulbs[i].material_override = bulb_on if on else bulb_off
	# 조이스틱 기울기 / 버튼 눌림
	if joystick_pivot:
		var tgt := Vector3(input_dir.y * 0.35, 0, -input_dir.x * 0.35) if state == State.MOVING else Vector3.ZERO
		joystick_pivot.rotation = joystick_pivot.rotation.lerp(tgt, min(1.0, delta * 14.0))
	if button_mat:
		var blink := state == State.MOVING and int(_bulb_t * 4.0) % 2 == 0
		button_mat.emission_energy_multiplier = 2.5 if blink else 0.5
	bill_led.emission_energy_multiplier = 2.0 if int(_bulb_t * 2.0) % 2 == 0 else 0.6
	if neon_mat:
		# 게임 중에는 네온이 숨 쉬듯 밝아졌다 어두워진다
		neon_mat.emission_energy_multiplier = (3.0 + 1.6 * sin(_bulb_t * 5.0)) if game_active else 2.6
	_update_labels()


func _update_labels() -> void:
	if credit_label == null:
		return
	credit_label.text = "CREDIT %02d" % credits
	if state == State.MOVING:
		timer_label.text = "TIME %02d" % int(ceil(time_left))
	elif state == State.IDLE:
		timer_label.text = "TIME --"
	else:
		timer_label.text = "TIME 00"
	name_label.text = String(settings.get("name", "인형뽑기"))
	price_label.text = price_text()


func _on_settings_changed(id: String) -> void:
	if id != machine_id:
		return
	settings = Game.get_settings(machine_id, kind)
	if claw and (claw.prong_count != int(settings["prong_count"]) or abs(rad_to_deg(claw.open_angle) - float(settings["open_angle"])) > 0.5):
		if state == State.IDLE:
			_rebuild_claw()
	_refresh_control_look()
	_update_labels()


func state_text() -> String:
	match state:
		State.IDLE:
			return "지폐를 넣어 주세요" if credits == 0 else "준비 중"
		State.MOVING:
			return "이동 중 · 남은 시간 %d초" % int(ceil(time_left))
		State.OPENING, State.DESCENDING:
			return "내려가는 중..."
		State.GRABBING:
			return "집는 중!"
		State.LIFTING, State.TOP_HOLD:
			return "올라가는 중..."
		State.RETURNING:
			return "배출구로 이동 중..."
		State.RELEASING, State.RESETTING:
			return "놓는 중"
	return ""


func is_busy() -> bool:
	return state != State.IDLE
