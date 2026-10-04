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

var head: AnimatableBody3D
var prongs: Array[RigidBody3D] = []
var hinges: Array[HingeJoint3D] = []
var cable: MeshInstance3D
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


func _build() -> void:
	_make_materials()
	var s := size
	if max_torque < 0:
		max_torque = 0.25 * pow(s, 5.5)
	head_radius = 0.042 * s
	head_height = 0.075 * s
	pivot_radius = 0.034 * s
	prong_mass = 0.05 * s

	head = AnimatableBody3D.new()
	head.name = "ClawHead"
	head.sync_to_physics = false
	head.collision_layer = LAYER_CLAW
	head.collision_mask = LAYER_PRIZE
	var hs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = head_radius
	cyl.height = head_height
	hs.shape = cyl
	hs.position.y = head_height * 0.5
	head.add_child(hs)
	_add_head_visual(head)
	add_child(head)

	for i in prong_count:
		var a := TAU * i / prong_count + (PI / 2.0 if prong_count == 2 else PI / 6.0)
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
		pm.friction = 0.55
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
	cm.top_radius = 0.0022 * max(s, 0.8)
	cm.bottom_radius = cm.top_radius
	cm.height = 1.0
	cm.radial_segments = 6
	cable.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.85, 0.85, 0.86)
	cmat.metallic = 0.8
	cmat.roughness = 0.35
	cable.material_override = cmat
	cable.top_level = true
	add_child(cable)


## 발 하나의 옆모습(로컬 XY 평면, +X = 바깥, 원점 = 힌지)
func _prong_profile() -> PackedVector2Array:
	var s := size
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
	var w := 0.016 * size
	var th := 0.007 * size
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
	mi.mesh = _sweep_strip(pts, w * 0.85, th * 0.45)
	mi.material_override = _metal
	prong.add_child(mi)
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


## 헤드를 옮긴다(물리 프레임에서 호출). top: 줄이 매달린 지점(캐리지)
func move_head(xf: Transform3D, top: Vector3) -> void:
	head.global_transform = xf
	var hook := xf * Vector3(0, head_height + 0.01 * size, 0)
	var len := top.distance_to(hook)
	if len > 0.001:
		var mid := (top + hook) * 0.5
		var dir := (top - hook).normalized()
		var b := Basis(Quaternion(Vector3.UP, dir)) if dir.cross(Vector3.UP).length() > 0.0001 else Basis()
		cable.global_transform = Transform3D(b.scaled(Vector3(1, len, 1)), mid)


## 집게 힘 0.0~1.0
func set_power(p: float) -> void:
	power = clamp(p, 0.0, 1.0)
	_apply_motor()


func open() -> void:
	closing = false
	_apply_motor()


func close(p: float) -> void:
	closing = true
	power = clamp(p, 0.0, 1.0)
	_apply_motor()


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
