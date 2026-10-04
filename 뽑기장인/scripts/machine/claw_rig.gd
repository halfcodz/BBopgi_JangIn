class_name ClawRig
extends Node3D
## 집게 헤드 + 발(prong). 헤드는 줄에 매달린 키네마틱 바디, 발은 모터 힌지로 연결된 실제 강체.
## 집게 힘 = 힌지 모터의 최대 토크(솔레노이드 힘). 힘이 약하면 인형 무게에 발이 벌어지며 미끄러진다.

const LAYER_ENV := 1
const LAYER_PRIZE := 2
const LAYER_CLAW := 4

@export var prong_count := 3
@export var size := 1.0  ## 1.0 = 큰 기계 집게, 0.62 = 작은 기계 집게
@export var max_torque := -1.0  ## 100% 힘일 때 발 하나의 최대 토크(N·m). 음수면 크기에 맞춰 자동
## "standard" = 한국식 금속 집게, "ufo" = 일본 프라이즈 매장(UFO 캐처형)의 투명 돔 헤드 + 긴 2팔 + 고무 손톱
@export var style := "standard"

var head: AnimatableBody3D
var prongs: Array[RigidBody3D] = []
var hinges: Array[HingeJoint3D] = []
var cable: MeshInstance3D
var wire: MeshInstance3D
var power := 1.0
var closing := false
var open_angle := deg_to_rad(42.0)
var close_angle := deg_to_rad(-9.0)
var head_radius := 0.042
var head_height := 0.075
var pivot_radius := 0.036
var prong_mass := 0.05
var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
## UFO형 팔이 버틸 수 있는 무게(팔 하나당, 힘 100% 기준, 뉴턴). 넘으면 팔이 밀려 벌어지며 미끄러진다.
## 실제 일본 기계처럼 무거운 피규어 상자는 통째로 들리지 않고 살짝 들렸다 미끄러지며 자리만 옮겨진다.
var arm_hold_full := 3.6  # 100% 힘이어도 상자(0.8kg)의 절반 무게(팔 하나당 약 3.9N)를 못 버틴다 → 통째로 들 수 없음
## 들어 올리는 동안에만 무게 한계를 적용(기계가 켜고 끈다)
var limit_load := false
var _yield_left: Array[float] = []
var _arm_mat: StandardMaterial3D
var _rubber_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func _make_materials() -> void:
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.82, 0.83, 0.86)
	_metal.metallic = 1.0
	_metal.roughness = 0.24
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.16, 0.16, 0.18)
	_dark.metallic = 0.6
	_dark.roughness = 0.4
	_arm_mat = StandardMaterial3D.new()
	_arm_mat.albedo_color = Color(0.93, 0.94, 0.96)
	_arm_mat.metallic = 0.55
	_arm_mat.roughness = 0.12
	_arm_mat.clearcoat_enabled = true
	_rubber_mat = StandardMaterial3D.new()
	_rubber_mat.albedo_color = Color(0.42, 0.44, 0.47)
	_rubber_mat.roughness = 0.85


func _build() -> void:
	_make_materials()
	var s := size
	if max_torque < 0:
		max_torque = 0.25 * pow(s, 5.5)
		if style == "ufo":
			max_torque *= 1.6  # 팔이 길어 같은 토크면 끝 힘이 약하다 → 보정
	head_radius = 0.042 * s
	head_height = 0.075 * s
	pivot_radius = 0.034 * s
	prong_mass = 0.05 * s
	if style == "ufo":
		# 사진 속 UFO형 집게: 가로로 긴 알약 모양 헤드(폭 15cm) 양 끝 아래에 팔 힌지
		head_radius = 0.06 * s
		head_height = 0.064 * s
		pivot_radius = 0.06 * s
		prong_mass = 0.06 * s
		close_angle = 0.0  # 다 오므리면 발끝 사이가 3cm 정도(평소 모습)

	head = AnimatableBody3D.new()
	head.name = "ClawHead"
	head.sync_to_physics = false
	head.collision_layer = LAYER_CLAW
	head.collision_mask = LAYER_PRIZE
	var hs := CollisionShape3D.new()
	if style == "ufo":
		var hb := BoxShape3D.new()
		hb.size = Vector3(0.15, head_height, 0.066) * Vector3(s, 1, s)
		hs.shape = hb
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = head_radius
		cyl.height = head_height
		hs.shape = cyl
	hs.position.y = head_height * 0.5
	head.add_child(hs)
	_add_head_visual(head)
	add_child(head)

	for i in prong_count:
		var a := TAU * i / prong_count + (0.0 if prong_count == 2 else PI / 6.0)
		var r := Vector3(cos(a), 0, sin(a))
		var t := r.cross(Vector3.UP)
		var basis := Basis(r, Vector3.UP, t)
		var pivot := r * pivot_radius
		var prong := RigidBody3D.new()
		prong.name = "Prong%d" % i
		prong.mass = prong_mass
		prong.collision_layer = LAYER_CLAW
		prong.collision_mask = LAYER_PRIZE | LAYER_ENV
		prong.can_sleep = false
		prong.continuous_cd = true
		prong.angular_damp = 2.0
		prong.contact_monitor = true
		prong.max_contacts_reported = 6
		var pm := PhysicsMaterial.new()
		pm.friction = 0.6 if style == "ufo" else 0.55
		pm.bounce = 0.0
		prong.physics_material_override = pm
		prong.transform = Transform3D(basis, pivot)
		_add_prong_shapes(prong)
		add_child(prong)
		prongs.append(prong)

		var hj := HingeJoint3D.new()
		hj.name = "Hinge%d" % i
		hj.transform = Transform3D(basis, pivot)
		add_child(hj)
		hj.node_a = hj.get_path_to(head)
		hj.node_b = hj.get_path_to(prong)
		hj.exclude_nodes_from_collision = true
		hj.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		# Jolt 힌지 각도는 기하학적 벌어짐 각도와 부호가 반대
		hj.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -open_angle)
		hj.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, -close_angle)
		hj.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
		hj.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -3.0)
		hj.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 10.0)
		hinges.append(hj)

	cable = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = (0.017 if style == "ufo" else 0.0022) * max(s, 0.8)
	cm.bottom_radius = cm.top_radius
	cm.height = 1.0
	cm.radial_segments = 20 if style == "ufo" else 6
	cable.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.8, 0.81, 0.84) if style == "ufo" else Color(0.85, 0.85, 0.86)
	cmat.metallic = 0.9 if style == "ufo" else 0.8
	cmat.roughness = 0.25 if style == "ufo" else 0.35
	cable.material_override = cmat
	cable.top_level = true
	add_child(cable)
	if style == "ufo":
		# 파이프 옆으로 내려오는 흰 전선(LED 전원)
		wire = MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.0028 * s
		wm.bottom_radius = wm.top_radius
		wm.height = 1.0
		wm.radial_segments = 6
		wire.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.95, 0.95, 0.95)
		wmat.roughness = 0.5
		wire.material_override = wmat
		wire.top_level = true
		add_child(wire)


## 발 하나의 옆모습(로컬 XY 평면, +X = 바깥, 원점 = 힌지)
func _prong_profile() -> PackedVector2Array:
	var s := size
	if style == "ufo":
		# 사진 속 UFO형 팔: 헤드 끝에서 바깥 아래로 뻗어 팔꿈치(>)를 이루고, 다시 안쪽으로 모여
		# 끝에 고무 발판이 안쪽을 향한다. 평소(다 오므린 상태)에는 발끝 사이가 3cm 정도.
		return PackedVector2Array([
			Vector2(0.0, 0.006) * s,
			Vector2(0.016, -0.012) * s,
			Vector2(0.062, -0.07) * s,
			Vector2(0.04, -0.1) * s,
			Vector2(-0.01, -0.142) * s,
			Vector2(-0.03, -0.158) * s,
			Vector2(-0.044, -0.164) * s,
		])
	return PackedVector2Array([
		Vector2(0.0, 0.004) * s,
		Vector2(0.004, -0.02) * s,
		Vector2(0.006, -0.06) * s,
		Vector2(0.0, -0.095) * s,
		Vector2(-0.012, -0.122) * s,
		Vector2(-0.026, -0.138) * s,
		Vector2(-0.034, -0.14) * s,
	])


func _add_prong_shapes(prong: RigidBody3D) -> void:
	var pts := _prong_profile()
	var ufo := style == "ufo"
	var w := (0.013 if ufo else 0.016) * size
	var th := (0.006 if ufo else 0.007) * size
	for k in pts.size() - 1:
		var a := Vector3(pts[k].x, pts[k].y, 0)
		var b := Vector3(pts[k + 1].x, pts[k + 1].y, 0)
		var seg := b - a
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(th, seg.length() + th * 0.5, w)
		cs.shape = bx
		var ang := atan2(seg.x, -seg.y)
		cs.transform = Transform3D(Basis(Vector3.BACK, ang), (a + b) * 0.5)
		prong.add_child(cs)
	# 발끝 고무 캡
	var tip := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = th * 0.9
	tip.shape = sp
	tip.position = Vector3(pts[pts.size() - 1].x, pts[pts.size() - 1].y, 0)
	prong.add_child(tip)
	# 보이는 메시: 얇은 금속 판을 곡선을 따라 스윕
	var mi := MeshInstance3D.new()
	# UFO형 팔은 정면에서 넓게 보이는 얇은 판(폭 1.1cm, 두께 5mm)
	mi.mesh = _sweep_strip(pts, 0.005 * size, 0.011 * size) if ufo else _sweep_strip(pts, w * 0.85, th * 0.45)
	mi.material_override = _arm_mat if ufo else _metal
	prong.add_child(mi)
	if ufo:
		# 팔 끝 고무 손톱(爪 커버): 끝 두 마디를 감싸는 두꺼운 고무
		var sleeve := MeshInstance3D.new()
		var tip_pts := PackedVector2Array([pts[pts.size() - 3].lerp(pts[pts.size() - 2], 0.5), pts[pts.size() - 2], pts[pts.size() - 1]])
		sleeve.mesh = _sweep_strip(tip_pts, 0.014 * size, 0.012 * size)
		sleeve.material_override = _rubber_mat
		prong.add_child(sleeve)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = th * 0.85
	cm.height = th * 1.7
	cap.mesh = cm
	cap.position = tip.position
	var rub := StandardMaterial3D.new()
	rub.albedo_color = Color(0.1, 0.1, 0.11)
	rub.roughness = 0.8
	cap.material_override = rub
	prong.add_child(cap)
	# 힌지 핀
	var pin := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.004 * size
	pc.bottom_radius = 0.004 * size
	pc.height = w * 1.25
	pin.mesh = pc
	pin.rotation = Vector3(PI / 2, 0, 0)
	pin.material_override = _dark
	prong.add_child(pin)


func _sweep_strip(pts: PackedVector2Array, width: float, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 촘촘하게 보간
	var dense: Array[Vector3] = []
	for k in pts.size() - 1:
		for j in 6:
			var t := j / 6.0
			var p := pts[k].lerp(pts[k + 1], t)
			dense.append(Vector3(p.x, p.y, 0))
	dense.append(Vector3(pts[pts.size() - 1].x, pts[pts.size() - 1].y, 0))
	var rings: Array = []
	for i in dense.size():
		var tan: Vector3
		if i == 0:
			tan = dense[1] - dense[0]
		elif i == dense.size() - 1:
			tan = dense[i] - dense[i - 1]
		else:
			tan = dense[i + 1] - dense[i - 1]
		tan = tan.normalized()
		var nrm := Vector3(-tan.y, tan.x, 0)  # 판의 두께 방향
		var z := Vector3(0, 0, 1)
		var c := dense[i]
		var hw := width * 0.5
		var ht := thick * 0.5
		rings.append([c + nrm * ht + z * hw, c + nrm * ht - z * hw, c - nrm * ht - z * hw, c - nrm * ht + z * hw])
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for k in 4:
			var a: Vector3 = r0[k]
			var b: Vector3 = r0[(k + 1) % 4]
			var c2: Vector3 = r1[k]
			var d: Vector3 = r1[(k + 1) % 4]
			var n := (b - a).cross(c2 - a).normalized()
			st.set_normal(n)
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c2)
			st.add_vertex(b)
			st.add_vertex(d)
			st.add_vertex(c2)
	st.generate_normals()
	return st.commit()


func _add_head_visual(h: Node3D) -> void:
	if style == "ufo":
		_add_ufo_head(h)
		return
	var s := size
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = head_radius * 0.82
	cm.bottom_radius = head_radius
	cm.height = head_height
	cm.radial_segments = 28
	body.mesh = cm
	body.position.y = head_height * 0.5
	body.material_override = _metal
	h.add_child(body)
	# 솔레노이드 커버 줄무늬, 위쪽 고리
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = head_radius * 1.02
	bm.bottom_radius = head_radius * 1.02
	bm.height = 0.012 * s
	bm.radial_segments = 28
	band.mesh = bm
	band.position.y = head_height * 0.22
	band.material_override = _dark
	h.add_child(band)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.006 * s
	tm.outer_radius = 0.011 * s
	ring.mesh = tm
	ring.rotation.x = PI / 2
	ring.position.y = head_height + 0.008 * s
	ring.material_override = _metal
	h.add_child(ring)
	var bottom := MeshInstance3D.new()
	var bt := CylinderMesh.new()
	bt.top_radius = head_radius * 0.98
	bt.bottom_radius = head_radius * 0.7
	bt.height = 0.012 * s
	bottom.mesh = bt
	bottom.position.y = -0.002 * s
	bottom.material_override = _dark
	h.add_child(bottom)


## 사진 속 UFO형 헤드: 가로로 긴 알약 모양 흰 몸통, 앞면 짙은 반투명 창 안에 LED 눈,
## 양 끝 둥근 마개 아래에 팔 힌지, 위로 은색 파이프
func _add_ufo_head(h: Node3D) -> void:
	var s := size
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.94, 0.95)
	white.roughness = 0.22
	white.metallic = 0.15
	white.clearcoat_enabled = true
	white.clearcoat = 0.8
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.78, 0.79, 0.82)
	silver.roughness = 0.2
	silver.metallic = 0.85
	var cy := head_height * 0.5
	# 몸통: 가로로 누운 캡슐(폭 15cm, 높이 6.4cm, 깊이 6.6cm)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.032 * s
	cap.height = 0.15 * s
	cap.radial_segments = 40
	cap.rings = 12
	body.mesh = cap
	body.rotation.z = PI / 2
	body.scale = Vector3(1.0, 1.0, 1.03)
	body.position.y = cy
	body.material_override = white
	h.add_child(body)
	# 몸통 둘레 은색 테(앞·뒤 테두리)
	for zz in [-1.0]:
		var rim := MeshInstance3D.new()
		var rc := CapsuleMesh.new()
		rc.radius = 0.0335 * s
		rc.height = 0.153 * s
		rc.radial_segments = 40
		rc.rings = 8
		rim.mesh = rc
		rim.rotation.z = PI / 2
		rim.scale = Vector3(1.0, 1.0, 0.12)
		rim.position = Vector3(0, cy, zz * 0.029 * s)
		rim.material_override = silver
		h.add_child(rim)
	# 앞면 짙은 반투명 창
	var win := MeshInstance3D.new()
	var wc := CapsuleMesh.new()
	wc.radius = 0.024 * s
	wc.height = 0.105 * s
	wc.radial_segments = 32
	wc.rings = 8
	win.mesh = wc
	win.rotation.z = PI / 2
	win.scale = Vector3(1.0, 1.0, 0.25)
	win.position = Vector3(0, cy, 0.03 * s)
	var wmat := StandardMaterial3D.new()
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(0.12, 0.13, 0.16, 0.72)
	wmat.roughness = 0.05
	wmat.metallic_specular = 1.0
	win.material_override = wmat
	h.add_child(win)
	# LED 눈: 빨강·노랑·파랑(+초록) 동그라미
	var eye_cols := [Color(1.0, 0.25, 0.3), Color(1.0, 0.8, 0.2), Color(0.25, 0.55, 1.0), Color(0.3, 0.95, 0.5)]
	var xs := [-0.024, -0.008, 0.008, 0.024]
	for k in 4:
		var dot := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.0068 * s
		dm.height = 0.0136 * s
		dm.radial_segments = 12
		dm.rings = 6
		dot.mesh = dm
		dot.position = Vector3(xs[k] * s, cy + (0.002 if k % 2 == 0 else -0.001) * s, 0.031 * s)
		var em := StandardMaterial3D.new()
		em.albedo_color = eye_cols[k]
		em.emission_enabled = true
		em.emission = eye_cols[k]
		em.emission_energy_multiplier = 4.0
		dot.material_override = em
		h.add_child(dot)
	# 양 끝 힌지 마개(팔이 끼워지는 곳)
	for sx in [-1.0, 1.0]:
		var hub := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.012 * s
		hm.bottom_radius = 0.012 * s
		hm.height = 0.05 * s
		hm.radial_segments = 16
		hub.mesh = hm
		hub.rotation.x = PI / 2
		hub.position = Vector3(sx * pivot_radius, 0.006 * s, 0)
		hub.material_override = silver
		h.add_child(hub)
	# 위쪽 파이프 받침
	var collar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02 * s
	cm.bottom_radius = 0.026 * s
	cm.height = 0.016 * s
	cm.radial_segments = 24
	collar.mesh = cm
	collar.position.y = head_height + 0.004 * s
	collar.material_override = silver
	h.add_child(collar)


## 헤드를 옮긴다(물리 프레임에서 호출). top: 줄이 매달린 지점(캐리지)
func move_head(xf: Transform3D, top: Vector3) -> void:
	head.global_transform = xf
	# 줄은 캐리지 아래 고정점(top)에서 헤드 위 고리까지 곧게 이어진다
	var hook := xf * Vector3(0, head_height + 0.012 * size, 0)
	var len := top.distance_to(hook)
	if len > 0.001:
		var mid := (top + hook) * 0.5
		var dir := (top - hook) / len
		var rot := Basis()
		if abs(dir.dot(Vector3.UP)) < 0.9999:
			rot = Basis(Quaternion(Vector3.UP, dir))
		cable.global_transform = Transform3D(rot * Basis.from_scale(Vector3(1, len, 1)), mid)
		if wire:
			# 흰 전선: 파이프 옆을 따라 내려와 헤드 위 왼쪽으로 들어간다
			var side := xf.basis.x.normalized() * 0.03 * size + xf.basis.z.normalized() * -0.012 * size
			wire.global_transform = Transform3D(rot * Basis.from_scale(Vector3(1, len, 1)), mid + side)


## 집게 힘 0.0~1.0
func set_power(p: float) -> void:
	power = clamp(p, 0.0, 1.0)
	_apply_motor()


## UFO형 팔: 벌린 상태를 '부드러운 스프링'으로 유지한다.
## 팔 끝이 상자 위를 누르면 팔이 살짝 꺾이며(더 벌어지며) 받아 주므로, 상자를 세게 밀어 날려 보내지 않는다.
const UFO_FLEX := deg_to_rad(35.0)
var arm_spring := 0.25  ## 벌린 자세를 유지하는 힘(N·m) – 이보다 세게 눌리면 팔이 꺾인다
var _open_target := 0.0


func open() -> void:
	closing = false
	_open_target = open_angle
	_set_open_limit(open_angle + UFO_FLEX if style == "ufo" else open_angle)
	_apply_motor()


## 배출구 위에서 놓을 때: UFO형 팔은 크게 벌려 끼인 상자도 떨어지게 한다
func open_release() -> void:
	closing = false
	_open_target = maxf(open_angle, deg_to_rad(62.0)) if style == "ufo" else open_angle
	_set_open_limit(_open_target + deg_to_rad(20.0) if style == "ufo" else open_angle)
	_apply_motor()


## 힌지 하나의 현재 벌어진 각도(라디안, + = 벌어짐)
func prong_angle(i: int) -> float:
	var rel := head.global_transform.basis.inverse() * prongs[i].global_transform.basis
	var local := hinges[i].transform.basis.inverse() * rel
	return atan2(local.x.y, local.x.x)


## 벌린 자세에서 팔이 눌려 더 꺾인 정도(가장 많이 꺾인 팔 기준)
func max_flex() -> float:
	var m := 0.0
	for i in prongs.size():
		m = maxf(m, prong_angle(i) - _open_target)
	return m


func _servo_open(delta: float) -> void:
	for i in prongs.size():
		var err := _open_target - prong_angle(i)  # + 면 더 벌려야 함
		var v := clampf(err * 10.0, -3.0, 3.0)
		hinges[i].set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -v)  # Jolt: 음수 = 벌어짐
		hinges[i].set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, arm_spring * delta)


func _set_open_limit(a: float) -> void:
	for hj in hinges:
		hj.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -a)


func close(p: float) -> void:
	closing = true
	power = clamp(p, 0.0, 1.0)
	_apply_motor()


func _physics_process(delta: float) -> void:
	if style != "ufo":
		return
	if not closing:
		_servo_open(delta)
		return
	if not limit_load:
		return
	if _yield_left.size() != prongs.size():
		_yield_left.resize(prongs.size())
		_yield_left.fill(0.0)
	var cap := arm_hold_full * power
	for i in prongs.size():
		var st := PhysicsServer3D.body_get_direct_state(prongs[i].get_rid())
		if st == null:
			continue
		var load := 0.0
		for c in st.get_contact_count():
			if st.get_contact_collider_object(c) is RigidBody3D:
				load += absf(st.get_contact_impulse(c).y) / delta
		var hj := hinges[i]
		if load > cap:
			_yield_left[i] = 0.08
		if _yield_left[i] > 0.0:
			# 버티지 못하고 팔이 살짝 벌어진다
			_yield_left[i] -= delta
			hj.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -0.9)
			hj.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, max_torque * maxf(power, 0.3) * delta)
			if _yield_left[i] <= 0.0:
				hj.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 4.0)
				hj.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, max_torque * power * delta)


func _apply_motor() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	for hj in hinges:
		if closing:
			hj.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 4.0)
			# Jolt: max_impulse 는 한 스텝당 충격량 → 토크 = impulse / dt
			hj.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, max_torque * power * dt)
		else:
			hj.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, -3.5)
			hj.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 2.0 * dt)
	for p in prongs:
		p.sleeping = false


## 발이 얼마나 오므려졌는지(0 = 활짝, 1 = 완전히 닫힘)
func closedness() -> float:
	var sum := 0.0
	for i in prongs.size():
		var rel := head.global_transform.basis.inverse() * prongs[i].global_transform.basis
		var r := hinges[i].transform.basis
		var local := r.inverse() * rel
		var ang := atan2(local.x.y, local.x.x)
		sum += inverse_lerp(open_angle, close_angle, ang)
	return sum / max(prongs.size(), 1)


## 발들이 무언가에 닿아 있는지(하강 정지 판정용)
## 집게 무게(줄이 느슨해진 뒤 상품 위에 얹힌 무게)로 닿아 있는 상품을 살짝 누른다. weight: 뉴턴
func press_touching(weight: float) -> void:
	var tips := tip_positions()
	var bodies := {}
	for i in prongs.size():
		for b in prongs[i].get_colliding_bodies():
			if b is RigidBody3D:
				bodies[b] = tips[i]
	if _probe_params:
		_probe_params.transform = head.global_transform * Transform3D(Basis(), Vector3(0, -0.004, 0))
		for hit in get_world_3d().direct_space_state.intersect_shape(_probe_params, 4):
			if hit["collider"] is RigidBody3D:
				bodies[hit["collider"]] = head.global_position
	if bodies.is_empty():
		return
	var f := weight / bodies.size()
	for b in bodies:
		var rb: RigidBody3D = b
		rb.sleeping = false
		rb.apply_force(Vector3.DOWN * f, bodies[b] - rb.global_position)


func touching_prize() -> bool:
	for p in prongs:
		for b in p.get_colliding_bodies():
			if b is RigidBody3D:
				return true
	return false


func touching_anything() -> int:
	var n := 0
	for p in prongs:
		n += p.get_contact_count()
	return n


## 헤드와 발들을 즉시 위치시킨다(초기화/텔레포트)
func snap_all(xf: Transform3D) -> void:
	head.global_transform = xf
	for i in prongs.size():
		var hj := hinges[i]
		var ang := open_angle if not closing else close_angle
		var local := hj.transform
		var rotb := local.basis * Basis(Vector3.BACK, ang)
		prongs[i].global_transform = xf * Transform3D(rotb, local.origin)
		prongs[i].linear_velocity = Vector3.ZERO
		prongs[i].angular_velocity = Vector3.ZERO
		prongs[i].reset_physics_interpolation()
	head.reset_physics_interpolation()


var _probe_shape: CylinderShape3D
var _probe_params: PhysicsShapeQueryParameters3D


## 헤드 바로 아래에 무언가(인형/바닥)가 받치고 있는지 – 줄이 느슨해지는 순간
func head_blocked(depth: float = 0.006) -> bool:
	if _probe_params == null:
		_probe_shape = CylinderShape3D.new()
		_probe_shape.radius = head_radius * 0.85
		_probe_shape.height = depth
		_probe_params = PhysicsShapeQueryParameters3D.new()
		_probe_params.shape = _probe_shape
		_probe_params.collision_mask = LAYER_PRIZE | LAYER_ENV
		_probe_params.collide_with_areas = false
	_probe_params.transform = head.global_transform * Transform3D(Basis(), Vector3(0, -depth * 0.5 - 0.001, 0))
	var hits := get_world_3d().direct_space_state.intersect_shape(_probe_params, 1)
	return not hits.is_empty()


func tip_positions() -> Array[Vector3]:
	var pts := _prong_profile()
	var tip := Vector3(pts[pts.size() - 1].x, pts[pts.size() - 1].y, 0)
	var out: Array[Vector3] = []
	for p in prongs:
		out.append(p.global_transform * tip)
	return out
