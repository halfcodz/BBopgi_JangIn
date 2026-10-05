class_name VendingMachine
extends Node3D
## 실제 음료 자판기처럼 생긴 자판기.
## 위쪽 진열창(조명 + 캔·페트병 견본 3단 + 가격표 + 선택 버튼), 가운데 광고판과 조작부
## (금액 표시창·지폐 투입구·동전 투입구·반환 버튼·교통카드 단말기), 아래 꺼내는 곳과 동전 반환구.
## 원하는 음료를 바라보고 [E]를 누르면 1,000원에 사서 꺼내 마실 수 있다.

const W := 0.98
const H := 1.83
const D := 0.72
const ZF := D * 0.5            # 문 앞면
const WIN_X := 0.44            # 진열창 가로 절반
const WIN_Y0 := 0.98
const WIN_Y1 := 1.68
const SLOT_DX := 0.105
const ROWS := [1.03, 1.30, 1.50]  # 각 단 선반 윗면 높이(아래 단은 페트병)
const PRICE := 1000

## 음료 목록: [이름, 라벨 칸 번호(4x4 아틀라스), 페트병인가, 액체색, 뚜껑색]
const DRINKS := [
	["콜락스 콜라", 0, false], ["별빛사이다", 1, false], ["아침커피", 2, false], ["볼트 에너지", 3, false],
	["복숭아 아이스티", 4, false], ["오렌지 100", 5, false], ["전통 식혜", 6, false], ["그레이프 피즈", 7, false],
	["라떼 한잔", 8, false], ["레몬 소다", 9, false], ["망고 스무디", 10, false],
	["맑은샘 생수", 11, true, Color(0.85, 0.93, 1.0, 0.18), Color(0.2, 0.45, 0.95)],
	["아쿠아 이온", 12, true, Color(0.9, 0.95, 1.0, 0.3), Color(0.15, 0.35, 0.85)],
	["보성 녹차", 13, true, Color(0.75, 0.82, 0.35, 0.55), Color(0.2, 0.55, 0.2)],
	["구수한 보리차", 14, true, Color(0.62, 0.38, 0.12, 0.6), Color(0.55, 0.3, 0.1)],
	["알로에", 15, true, Color(0.9, 0.95, 0.85, 0.45), Color(0.3, 0.65, 0.3)],
]
## 단마다 진열 순서(아래 → 위)
const LAYOUT := [
	[11, 12, 13, 14, 15, 11, 12, 13],
	[8, 9, 10, 0, 3, 1, 5, 2],
	[0, 1, 2, 3, 4, 5, 6, 7],
]
const SOLD_OUT := [[1, 4]]  # (단, 칸) 품절 표시

var _label_tex: Texture2D
var _can_mesh: ArrayMesh
var _pet_mesh: ArrayMesh
var _metal: StandardMaterial3D
var _label_mats := {}
var _slots: Array = []   # {drink, row, col, pos, button}
var _btn_on: StandardMaterial3D
var _btn_hot: StandardMaterial3D
var _btn_off: StandardMaterial3D
var _display: Label3D
var _busy := false
var _in_port := -1        # 꺼내는 곳에 있는 음료 번호
var _port_node: Node3D
var _aim := -1
var aim_override := -1   # 테스트용: 바라보는 칸을 직접 지정
var _tap_ray: Array = []  # 휴대폰: 화면을 톡 누른 방향(있으면 시선 대신 사용)


func _ready() -> void:
	_label_tex = load("res://assets/textures/shop/vm_labels.png")
	_metal = Build.mat(Color(0.8, 0.81, 0.84), 0.22, 1.0)
	_build_cabinet()
	_build_display()
	_build_controls()
	_build_port()
	Build.interact_body(self, self, Vector3(W, H - 0.1, 0.14), Vector3(0, H * 0.5, ZF + 0.02))
	if Game.touch:
		# 휴대폰: 움직이지 않는 부품을 재질별로 합쳐 그리기 횟수를 줄인다(버튼처럼 바뀌는 부품은 그대로)
		RenderBatcher.merge_static.call_deferred(self, RenderBatcher.referenced_nodes(self), RenderBatcher.referenced_materials(self))


# ------------------------------------------------------------------ 몸체
func _build_cabinet() -> void:
	var body := Build.mat(Color(0.95, 0.95, 0.96), 0.28, 0.15)
	body.clearcoat_enabled = true
	body.clearcoat_roughness = 0.2
	var dark := Build.mat(Color(0.12, 0.12, 0.14), 0.6)
	var blue := Build.mat(Color(0.06, 0.32, 0.78), 0.3, 0.2)
	blue.clearcoat_enabled = true
	var side_tex := StandardMaterial3D.new()
	side_tex.albedo_texture = load("res://assets/textures/shop/vm_side.png")
	side_tex.roughness = 0.25
	side_tex.clearcoat_enabled = true
	# 속이 빈 철제 상자(뒤판·옆판·윗판)
	Build.box(self, Vector3(W - 0.02, H - 0.1, 0.02), Vector3(0, 0.08 + (H - 0.1) * 0.5, -D * 0.5 + 0.01), dark)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(0.02, H - 0.1, D - 0.06), Vector3(sx * (W * 0.5 - 0.01), 0.08 + (H - 0.1) * 0.5, -0.03), body)
		# 옆면 랩핑 스티커(옆판보다 살짝 바깥)
		_quad(Vector2(D - 0.14, H - 0.24), Vector3(sx * (W * 0.5 + 0.002), 0.08 + (H - 0.1) * 0.5, -0.03), side_tex, sx * PI * 0.5)
	Build.box(self, Vector3(W + 0.012, 0.02, D + 0.012), Vector3(0, H - 0.01, 0), blue)
	# 받침(안쪽으로 들어간 걸레받이) + 조절 발
	Build.box(self, Vector3(W - 0.06, 0.08, D - 0.1), Vector3(0, 0.04, -0.02), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Build.cyl(self, 0.022, 0.02, Vector3(sx * (W * 0.5 - 0.06), 0.01, sz * (D * 0.5 - 0.08)), _metal)
	# 앞문: 위 간판 칸 / 진열창 양옆 기둥 / 아래 큰 판
	var t := 0.06
	var zc := ZF - t * 0.5
	Build.box(self, Vector3(W, H - 0.02 - WIN_Y1, t), Vector3(0, (WIN_Y1 + H - 0.02) * 0.5, zc), blue)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(W * 0.5 - WIN_X, WIN_Y1 - WIN_Y0, t), Vector3(sx * (W * 0.5 + WIN_X) * 0.5, (WIN_Y0 + WIN_Y1) * 0.5, zc), body)
	Build.box(self, Vector3(W, WIN_Y0 - 0.08, t), Vector3(0, 0.08 + (WIN_Y0 - 0.08) * 0.5, zc), body)
	# 아래쪽 파란 띠
	Build.box(self, Vector3(W - 0.04, 0.05, 0.004), Vector3(0, 0.115, ZF + 0.002), blue)
	# 문 손잡이 겸 자물쇠(오른쪽)
	Build.box(self, Vector3(0.03, 0.16, 0.025), Vector3(W * 0.5 - 0.03, 0.5, ZF + 0.012), _metal)
	Build.cyl(self, 0.012, 0.01, Vector3(W * 0.5 - 0.03, 0.62, ZF + 0.005), _metal, Vector3(PI / 2, 0, 0))
	# 간판(빛나는 아크릴)
	var hm := StandardMaterial3D.new()
	hm.albedo_texture = load("res://assets/textures/shop/vm_header.png")
	hm.emission_enabled = true
	hm.emission_texture = hm.albedo_texture
	hm.emission_energy_multiplier = 1.3
	_quad(Vector2(W - 0.06, H - 0.02 - WIN_Y1 - 0.02), Vector3(0, (WIN_Y1 + H - 0.02) * 0.5, ZF + 0.002), hm)
	Build.blocker(self, Vector3(W, H, D), Vector3(0, H * 0.5, 0))


func _quad(size: Vector2, pos: Vector3, m: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)
	return mi


# ------------------------------------------------------------------ 진열창
func _build_display() -> void:
	# 안쪽 공간: 빛나는 뒷판, 은색 옆벽, 위 형광등
	var back_z := -0.04
	var depth := ZF - 0.06 - back_z
	Build.box(self, Vector3(WIN_X * 2.0, WIN_Y1 - WIN_Y0, 0.01), Vector3(0, (WIN_Y0 + WIN_Y1) * 0.5, back_z), Build.glow(Color(0.93, 0.97, 1.0), 1.1))
	var wall := Build.mat(Color(0.86, 0.88, 0.9), 0.2, 0.6)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(0.01, WIN_Y1 - WIN_Y0, depth), Vector3(sx * (WIN_X + 0.004), (WIN_Y0 + WIN_Y1) * 0.5, back_z + depth * 0.5), wall)
	Build.box(self, Vector3(WIN_X * 2.0, 0.01, depth), Vector3(0, WIN_Y1 + 0.004, back_z + depth * 0.5), wall)
	Build.box(self, Vector3(WIN_X * 2.0, 0.01, depth), Vector3(0, WIN_Y0 - 0.004, back_z + depth * 0.5), wall)
	Build.cyl(self, 0.009, WIN_X * 2.0 - 0.06, Vector3(0, WIN_Y1 - 0.03, 0.22), Build.glow(Color(1, 1, 1), 3.0), Vector3(0, 0, PI / 2))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, WIN_Y1 - 0.06, 0.18)
	lamp.light_color = Color(0.95, 0.98, 1.0)
	lamp.light_energy = 0.7
	lamp.omni_range = 0.9
	lamp.omni_attenuation = 1.4
	add_child(lamp)
	# 견본 음료
	_can_mesh = _make_can()
	_pet_mesh = _make_pet()
	_btn_on = Build.glow(Color(0.25, 0.7, 1.0), 1.6)
	_btn_hot = Build.glow(Color(0.6, 1.0, 0.7), 3.0)
	_btn_off = Build.glow(Color(1.0, 0.18, 0.15), 1.6)
	var shelf := Build.mat(Color(0.92, 0.93, 0.95), 0.3, 0.4)
	var rail := Build.mat(Color(0.1, 0.1, 0.12), 0.5)
	for r in ROWS.size():
		var y: float = ROWS[r]
		Build.box(self, Vector3(WIN_X * 2.0, 0.01, 0.16), Vector3(0, y - 0.005, 0.2), shelf)
		# 가격·버튼 레일
		Build.box(self, Vector3(WIN_X * 2.0, 0.042, 0.012), Vector3(0, y - 0.024, 0.284), rail)
		for c in 8:
			var di: int = LAYOUT[r][c]
			var x := (c - 3.5) * SLOT_DX
			var sold := SOLD_OUT.has([r, c])
			var mi := MeshInstance3D.new()
			var info: Array = DRINKS[di]
			mi.mesh = _pet_mesh if info[2] else _can_mesh
			_apply_mats(mi, di)
			mi.position = Vector3(x, y, 0.2)
			mi.rotation.y = randf_range(-0.12, 0.12)
			add_child(mi)
			var price := Build.text(self, Game.won(PRICE).replace("원", "") if not sold else "품절", Vector3(x - 0.012, y - 0.024, 0.2915), 26, 0.0007,
				Color(1.0, 0.95, 0.6) if not sold else Color(1.0, 0.35, 0.3), Color(0, 0, 0, 0), "res://assets/fonts/DoHyeon-Regular.ttf")
			price.outline_size = 0
			var btn := Build.box(self, Vector3(0.026, 0.016, 0.008), Vector3(x + 0.03, y - 0.024, 0.293), _btn_off if sold else _btn_on)
			_slots.append({"drink": di, "row": r, "col": c, "pos": Vector3(x, y, 0.2), "button": btn, "sold": sold})
	# 유리(살짝 푸른 반사) + 테두리 몰딩
	var g := Build.glass(Color(0.85, 0.93, 1.0, 0.06))
	Build.box(self, Vector3(WIN_X * 2.0, WIN_Y1 - WIN_Y0, 0.006), Vector3(0, (WIN_Y0 + WIN_Y1) * 0.5, ZF - 0.03), g)
	var trim := Build.mat(Color(0.75, 0.77, 0.8), 0.2, 1.0)
	for sy in [WIN_Y0, WIN_Y1]:
		Build.box(self, Vector3(WIN_X * 2.0 + 0.03, 0.014, 0.012), Vector3(0, sy, ZF + 0.004), trim)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(0.014, WIN_Y1 - WIN_Y0 + 0.03, 0.012), Vector3(sx * (WIN_X + 0.008), (WIN_Y0 + WIN_Y1) * 0.5, ZF + 0.004), trim)


func _apply_mats(mi: MeshInstance3D, di: int) -> void:
	var info: Array = DRINKS[di]
	var lab := _label_mat(di, info[2])
	if info[2]:
		var liquid := Build.mat(info[3], 0.05, 0.0)
		liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		liquid.metallic_specular = 0.9
		mi.set_surface_override_material(0, liquid)
		mi.set_surface_override_material(1, lab)
		mi.set_surface_override_material(2, Build.mat(info[4], 0.35))
	else:
		mi.set_surface_override_material(0, _metal)
		mi.set_surface_override_material(1, lab)


func _label_mat(di: int, pet: bool) -> StandardMaterial3D:
	if _label_mats.has(di):
		return _label_mats[di]
	var cell: int = DRINKS[di][1]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _label_tex
	m.uv1_scale = Vector3(0.25, 0.25, 1)
	m.uv1_offset = Vector3((cell % 4) * 0.25, (cell / 4) * 0.25, 0)
	m.roughness = 0.35 if pet else 0.28
	m.metallic = 0.0 if pet else 0.45
	m.clearcoat_enabled = true
	_label_mats[di] = m
	return m


# ------------------------------------------------------------------ 캔·페트병 모양(회전체)
## 바닥 → 위 순서의 (반지름, 높이) 점들을 돌려 면을 만든다. uv_v: 라벨처럼 세로로 텍스처를 붙일지
func _lathe(mesh: ArrayMesh, pts: PackedVector2Array, label: bool, segs := 32) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0 := pts[0].y
	var y1 := pts[pts.size() - 1].y
	var nrm2: Array[Vector2] = []
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var tg := (b - a).normalized()
		nrm2.append(Vector2(tg.y, -tg.x))
	for i in pts.size() - 1:
		for j in segs:
			var th0 := -PI + TAU * j / segs
			var th1 := -PI + TAU * (j + 1) / segs
			var quad := [[i, th0, j], [i + 1, th0, j], [i, th1, j + 1], [i + 1, th1, j + 1]]
			var v: Array = []
			for q in quad:
				var p := pts[q[0]]
				var n2: Vector2 = nrm2[q[0]]
				var th: float = q[1]
				var uv := Vector2(float(q[2]) / segs, 1.0 - (p.y - y0) / maxf(y1 - y0, 0.0001)) if label else Vector2(float(q[2]) / segs, 0.5)
				v.append([Vector3(p.x * sin(th), p.y, p.x * cos(th)), Vector3(n2.x * sin(th), n2.y, n2.x * cos(th)).normalized(), uv])
			for k in [0, 1, 2, 1, 3, 2]:
				st.set_normal(v[k][1])
				st.set_uv(v[k][2])
				st.add_vertex(v[k][0])
	st.commit(mesh)


func _make_can() -> ArrayMesh:
	var m := ArrayMesh.new()
	# 0: 아래·위 알루미늄 부분(한 면으로 묶으려고 따로따로 넣는다)
	var st_pts := PackedVector2Array([Vector2(0.0, 0.007), Vector2(0.02, 0.003), Vector2(0.026, 0.0), Vector2(0.031, 0.004), Vector2(0.033, 0.012)])
	_lathe(m, st_pts, false)
	_lathe(m, PackedVector2Array([Vector2(0.033, 0.012), Vector2(0.033, 0.104)]), true)
	var top := PackedVector2Array([Vector2(0.033, 0.104), Vector2(0.031, 0.112), Vector2(0.027, 0.118), Vector2(0.0275, 0.1225), Vector2(0.026, 0.1232), Vector2(0.0245, 0.1195), Vector2(0.0, 0.118)])
	_lathe(m, top, false)
	return _merge_surfaces(m, [[0, 2], [1]])


func _make_pet() -> ArrayMesh:
	var m := ArrayMesh.new()
	_lathe(m, PackedVector2Array([Vector2(0.0, 0.005), Vector2(0.02, 0.0), Vector2(0.03, 0.002), Vector2(0.034, 0.012), Vector2(0.034, 0.055)]), false)
	_lathe(m, PackedVector2Array([Vector2(0.0342, 0.055), Vector2(0.0342, 0.14)]), true)
	_lathe(m, PackedVector2Array([Vector2(0.034, 0.14), Vector2(0.033, 0.15), Vector2(0.028, 0.168), Vector2(0.02, 0.182), Vector2(0.0135, 0.19), Vector2(0.0135, 0.193)]), false)
	_lathe(m, PackedVector2Array([Vector2(0.0, 0.192), Vector2(0.0148, 0.192), Vector2(0.0148, 0.207), Vector2(0.012, 0.2095), Vector2(0.0, 0.2095)]), false)
	return _merge_surfaces(m, [[0, 2], [1], [3]])


## 여러 표면을 묶어 재질 칸 수를 줄인다(groups: 새 표면마다 합칠 옛 표면 번호들)
func _merge_surfaces(src: ArrayMesh, groups: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for g in groups:
		var st := SurfaceTool.new()
		for si in g:
			st.append_from(src, si, Transform3D.IDENTITY)
		st.commit(out)
	return out


# ------------------------------------------------------------------ 광고판 + 조작부
func _build_controls() -> void:
	var z := ZF + 0.002
	# 광고판(빛나는 아크릴, 은색 테)
	var ad := StandardMaterial3D.new()
	ad.albedo_texture = load("res://assets/textures/shop/vm_ad.png")
	ad.emission_enabled = true
	ad.emission_texture = ad.albedo_texture
	ad.emission_energy_multiplier = 0.9
	var trim := Build.mat(Color(0.75, 0.77, 0.8), 0.2, 1.0)
	var ax := -0.13
	_quad(Vector2(0.6, 0.375), Vector3(ax, 0.75, z + 0.003), ad)
	Build.box(self, Vector3(0.62, 0.395, 0.003), Vector3(ax, 0.75, ZF + 0.0005), trim)
	# 조작판(검은 금속)
	var px := 0.32
	var panel := Build.mat(Color(0.16, 0.17, 0.19), 0.35, 0.6)
	Build.box(self, Vector3(0.26, 0.5, 0.012), Vector3(px, 0.69, ZF + 0.006), panel)
	var zc := ZF + 0.012
	var font := "res://assets/fonts/DoHyeon-Regular.ttf"
	# 투입 금액 표시창
	Build.box(self, Vector3(0.2, 0.06, 0.006), Vector3(px, 0.89, zc + 0.003), Build.mat(Color(0.02, 0.02, 0.02), 0.1))
	Build.text(self, "투입금액", Vector3(px, 0.93, zc + 0.002), 22, 0.0007, Color(0.85, 0.87, 0.9), Color(0, 0, 0, 0), font).outline_size = 0
	_display = Build.text(self, "0", Vector3(px + 0.08, 0.889, zc + 0.0065), 64, 0.0007, Color(1.0, 0.25, 0.12), Color(0, 0, 0, 0), font)
	_display.outline_size = 0
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_display.offset = Vector2(-50, 0)
	# 지폐 투입구: 은색 테 + 검은 틈 + 초록 안내등
	Build.box(self, Vector3(0.15, 0.045, 0.02), Vector3(px, 0.81, zc + 0.01), _metal)
	Build.box(self, Vector3(0.11, 0.006, 0.022), Vector3(px, 0.81, zc + 0.012), Build.mat(Color(0, 0, 0), 0.8))
	for k in 3:
		Build.box(self, Vector3(0.012, 0.006, 0.002), Vector3(px - 0.045 + k * 0.045, 0.795, zc + 0.021), Build.glow(Color(0.2, 1.0, 0.3), 2.0))
	Build.text(self, "지폐 투입구 (천원권)", Vector3(px, 0.775, zc + 0.002), 20, 0.0007, Color(0.85, 0.87, 0.9), Color(0, 0, 0, 0), font).outline_size = 0
	# 동전 투입구 + 반환 버튼
	Build.box(self, Vector3(0.05, 0.07, 0.014), Vector3(px + 0.07, 0.71, zc + 0.007), _metal)
	Build.box(self, Vector3(0.005, 0.03, 0.016), Vector3(px + 0.07, 0.715, zc + 0.008), Build.mat(Color(0, 0, 0), 0.8))
	Build.text(self, "동전", Vector3(px + 0.07, 0.665, zc + 0.002), 20, 0.0007, Color(0.85, 0.87, 0.9), Color(0, 0, 0, 0), font).outline_size = 0
	Build.cyl(self, 0.022, 0.016, Vector3(px - 0.05, 0.71, zc + 0.008), Build.mat(Color(0.85, 0.15, 0.15), 0.3), Vector3(PI / 2, 0, 0))
	Build.text(self, "반환", Vector3(px - 0.05, 0.665, zc + 0.002), 20, 0.0007, Color(0.85, 0.87, 0.9), Color(0, 0, 0, 0), font).outline_size = 0
	# 교통카드 단말기
	Build.box(self, Vector3(0.12, 0.085, 0.018), Vector3(px, 0.565, zc + 0.009), Build.mat(Color(0.05, 0.05, 0.06), 0.2, 0.3))
	Build.cyl(self, 0.026, 0.002, Vector3(px, 0.57, zc + 0.019), Build.glow(Color(0.3, 0.75, 1.0), 1.5), Vector3(PI / 2, 0, 0))
	Build.cyl(self, 0.022, 0.003, Vector3(px, 0.57, zc + 0.019), Build.mat(Color(0.05, 0.05, 0.06), 0.2), Vector3(PI / 2, 0, 0))
	Build.text(self, "카드", Vector3(px, 0.537, zc + 0.019), 18, 0.0007, Color(0.6, 0.85, 1.0), Color(0, 0, 0, 0), font).outline_size = 0
	# 문 아래쪽 안내 글씨
	Build.text(self, "원하는 음료의 버튼을 누르세요", Vector3(ax, 0.515, z), 30, 0.0008, Color(0.1, 0.3, 0.7), Color(0, 0, 0, 0), "res://assets/fonts/Jua-Regular.ttf").outline_size = 0


# ------------------------------------------------------------------ 꺼내는 곳 + 동전 반환구
func _build_port() -> void:
	var px := -0.13
	var py := 0.27
	var pw := 0.6
	var ph := 0.2
	var out := 0.07
	var bez := Build.mat(Color(0.2, 0.21, 0.24), 0.35, 0.4)
	var inside := Build.mat(Color(0.03, 0.03, 0.035), 0.9)
	# 튀어나온 상자(위·아래·양옆) + 안쪽 검은 바닥과 뒷벽
	Build.box(self, Vector3(pw + 0.04, 0.02, out), Vector3(px, py + ph * 0.5 + 0.01, ZF + out * 0.5), bez)
	Build.box(self, Vector3(pw + 0.04, 0.02, out), Vector3(px, py - ph * 0.5 - 0.01, ZF + out * 0.5), bez)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(0.02, ph, out), Vector3(px + sx * (pw * 0.5 + 0.01), py, ZF + out * 0.5), bez)
	Build.box(self, Vector3(pw, ph, 0.004), Vector3(px, py, ZF + 0.002), inside)
	Build.box(self, Vector3(pw, 0.006, out), Vector3(px, py - ph * 0.5 + 0.003, ZF + out * 0.5), inside)
	# 위에 경첩 달린 반투명 덮개(아래쪽이 안으로 살짝 들어감)
	var flap_pivot := Node3D.new()
	flap_pivot.position = Vector3(px, py + ph * 0.5 - 0.004, ZF + out - 0.006)
	flap_pivot.rotation.x = 0.16
	add_child(flap_pivot)
	var smoke := Build.glass(Color(0.12, 0.13, 0.16, 0.6))
	smoke.roughness = 0.15
	Build.box(flap_pivot, Vector3(pw - 0.01, ph - 0.012, 0.005), Vector3(0, -(ph - 0.012) * 0.5, 0), smoke)
	Build.text(flap_pivot, "PUSH", Vector3(0, -0.035, 0.004), 30, 0.0009, Color(1, 1, 1, 0.8), Color(0, 0, 0, 0), "res://assets/fonts/DoHyeon-Regular.ttf").outline_size = 0
	Build.text(self, "꺼내는 곳", Vector3(px, py + ph * 0.5 + 0.035, ZF + 0.002), 30, 0.0008, Color(0.2, 0.22, 0.26), Color(0, 0, 0, 0), "res://assets/fonts/Jua-Regular.ttf").outline_size = 0
	_port_node = Node3D.new()
	_port_node.position = Vector3(px, py - ph * 0.5 + 0.04, ZF + 0.032)
	add_child(_port_node)
	# 동전 반환구(오른쪽 아래 작은 컵)
	var cx := 0.33
	var cy := 0.27
	Build.box(self, Vector3(0.11, 0.08, 0.004), Vector3(cx, cy, ZF + 0.002), inside)
	Build.box(self, Vector3(0.13, 0.012, 0.04), Vector3(cx, cy - 0.046, ZF + 0.02), _metal)
	Build.box(self, Vector3(0.13, 0.012, 0.04), Vector3(cx, cy + 0.046, ZF + 0.02), _metal)
	for sx in [-1.0, 1.0]:
		Build.box(self, Vector3(0.012, 0.08, 0.04), Vector3(cx + sx * 0.059, cy, ZF + 0.02), _metal)
	Build.text(self, "동전 반환", Vector3(cx, cy + 0.075, ZF + 0.002), 24, 0.0007, Color(0.2, 0.22, 0.26), Color(0, 0, 0, 0), "res://assets/fonts/DoHyeon-Regular.ttf").outline_size = 0


# ------------------------------------------------------------------ 상호작용
## 플레이어가 바라보는 곳이 어느 음료 칸인지
func _aimed_slot() -> int:
	if aim_override >= 0:
		return aim_override
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var inv := global_transform.affine_inverse()
	var o: Vector3 = inv * cam.global_position
	var d: Vector3 = inv.basis * (-cam.global_basis.z)
	if _tap_ray.size() == 2:
		o = inv * (_tap_ray[0] as Vector3)
		d = inv.basis * (_tap_ray[1] as Vector3)
	if absf(d.z) < 0.001:
		return -1
	var t := (0.27 - o.z) / d.z
	if t < 0.0:
		return -1
	var p := o + d * t
	if absf(p.x) > WIN_X or p.y < WIN_Y0 or p.y > WIN_Y1:
		return -1
	var best := -1
	var bd := 1e9
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var sp: Vector3 = s["pos"]
		var top := 0.21 if DRINKS[s["drink"]][2] else 0.125
		var dx := absf(p.x - sp.x)
		var dy := 0.0 if (p.y > sp.y - 0.05 and p.y < sp.y + top) else 1.0
		if dx < SLOT_DX * 0.5 and dy == 0.0 and dx < bd:
			bd = dx
			best = i
	return best


func _set_aim(i: int) -> void:
	if i == _aim:
		return
	if _aim >= 0 and not _slots[_aim]["sold"]:
		_slots[_aim]["button"].material_override = _btn_on
	_aim = i
	if _aim >= 0 and not _slots[_aim]["sold"]:
		_slots[_aim]["button"].material_override = _btn_hot


func _process(_delta: float) -> void:
	# 바라보는 동안만 버튼 강조(멀어지면 꺼짐)
	if _aim >= 0:
		var cam := get_viewport().get_camera_3d()
		if cam == null or cam.global_position.distance_to(global_position) > 3.0:
			_set_aim(-1)


func interact_prompt() -> String:
	if _in_port >= 0:
		_set_aim(-1)
		return "[E] 꺼내는 곳에서 %s 꺼내 마시기" % DRINKS[_in_port][0]
	var i := _aimed_slot()
	_set_aim(i)
	if i < 0:
		return "[E] 음료 자판기: 마시고 싶은 음료를 바라보세요"
	if _slots[i]["sold"]:
		return "%s - 품절" % DRINKS[_slots[i]["drink"]][0]
	return "[E] %s 사기 (%s)" % [DRINKS[_slots[i]["drink"]][0], Game.won(PRICE)]


## 휴대폰: 진열창의 음료를 직접 톡 누르면 그 음료를 산다
func interact_tap(p, origin: Vector3, dir: Vector3) -> void:
	_tap_ray = [origin, dir]
	var slot := _aimed_slot()
	if slot < 0 and _in_port < 0:
		_tap_ray = []
		Game.say("진열창의 음료를 톡 눌러 고르세요")
		return
	await interact(p)
	_tap_ray = []


func interact(_player) -> void:
	if _busy:
		return
	if _in_port >= 0:
		Game.say("%s 꿀꺽꿀꺽… 시원하다!" % DRINKS[_in_port][0])
		Sfx.play("credit", -6.0)
		for c in _port_node.get_children():
			c.queue_free()
		_in_port = -1
		return
	var i := _aimed_slot()
	if i < 0:
		Game.say("진열창의 음료를 바라보고 누르기 버튼을 누르세요" if Game.touch else "진열창의 음료를 바라보고 E를 누르세요")
		return
	var s: Dictionary = _slots[i]
	if s["sold"]:
		Game.say("앗, 품절이에요")
		Sfx.play("miss", -8.0)
		return
	var where := global_transform * Vector3(0.32, 0.8, ZF)
	if Game.has_bill("1000"):
		Game.take_bill("1000")
		Sfx.play_at("bill_insert", where, -6.0)
	elif int(Game.wallet.get("500", 0)) >= 2:
		Game.take_bill("500")
		Game.take_bill("500")
		Sfx.play_at("coin", where)
	else:
		Game.say("천 원짜리나 500원 동전이 필요해요 (교환기를 이용하세요)")
		return
	Game.record_spend(PRICE)
	Game.stats["drinks"] = int(Game.stats.get("drinks", 0)) + 1
	_busy = true
	_display.text = "%d" % PRICE
	await get_tree().create_timer(0.45).timeout
	Sfx.play_at("button", global_transform * (s["pos"] as Vector3), -4.0)
	var btn: MeshInstance3D = s["button"]
	for k in 3:
		btn.material_override = _btn_on
		await get_tree().create_timer(0.08).timeout
		btn.material_override = _btn_hot
		await get_tree().create_timer(0.08).timeout
	_display.text = "0"
	await get_tree().create_timer(0.35).timeout
	# 덜컹! 꺼내는 곳에 음료가 눕는다
	var di: int = s["drink"]
	var mi := MeshInstance3D.new()
	mi.mesh = _pet_mesh if DRINKS[di][2] else _can_mesh
	_apply_mats(mi, di)
	mi.rotation = Vector3(0, 0, PI / 2)
	var len := 0.21 if DRINKS[di][2] else 0.123
	mi.position = Vector3(len * 0.5, 0.06, 0)
	_port_node.add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "position:y", 0.006, 0.05)
	tw.tween_property(mi, "position:y", 0.0, 0.05)
	Sfx.play_at("chute_thud", global_transform * Vector3(-0.13, 0.25, ZF), -2.0, 1.5)
	_in_port = di
	if not _slots[i]["sold"]:
		btn.material_override = _btn_hot if _aim == i else _btn_on
	_busy = false
