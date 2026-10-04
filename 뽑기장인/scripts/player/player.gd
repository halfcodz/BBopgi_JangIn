class_name Player
extends CharacterBody3D
## 1인칭 손님/사장님. 걸어다니며 기계 앞에서 E 로 플레이.

signal mode_changed(mode: int)
signal focus_changed(target)

enum Mode { WALK, MACHINE, UI }

const WALK_SPEED := 2.4
const RUN_SPEED := 4.2

var mode := Mode.WALK
var camera: Camera3D
var head: Node3D
var ray: RayCast3D
var focus = null
var machine = null  ## 지금 플레이 중인 기계
var view_index := 0
var _yaw := 0.0
var _pitch := 0.0
var _look_off := Vector2.ZERO
var _cam_tween: Tween
var _step_t := 0.0
var _step_i := 0
var ui_open := false
var zoom := 0.0  ## +/- 키로 확대(양수) / 축소(음수), 도 단위
const VIEW_NAMES := ["정면", "오른쪽 비스듬히", "왼쪽 비스듬히", "가까이"]


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 70
	camera.near = 0.03
	camera.current = true
	camera.far = 80.0
	# 플레이어(카메라)는 매 프레임 직접 움직이므로 물리 보간에서 제외 – 기계·인형만 보간해 부드럽게
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.4)
	ray.collision_mask = 16
	ray.collide_with_areas = true
	camera.add_child(ray)
	_yaw = rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := Game.mouse_sensitivity
		if mode == Mode.WALK:
			_yaw -= event.relative.x * s
			_pitch = clamp(_pitch - event.relative.y * s, -1.35, 1.35)
			rotation.y = _yaw
			head.rotation.x = _pitch
		elif mode == Mode.MACHINE:
			# 기계 앞에서는 고개만 살짝 돌려 볼 수 있다
			_look_off.x = clamp(_look_off.x - event.relative.x * s, -0.6, 0.6)
			_look_off.y = clamp(_look_off.y - event.relative.y * s, -0.45, 0.45)
	elif event is InputEventMouseButton and event.pressed and not ui_open:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_add_zoom(4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_add_zoom(-4.0)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.owner_mode:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _base_fov() -> float:
	return 62.0 if mode == Mode.MACHINE else 70.0


func _add_zoom(d: float) -> void:
	zoom = clamp(zoom + d, -20.0, 45.0)


func _process(delta: float) -> void:
	if not ui_open:
		if Input.is_action_pressed("zoom_in"):
			_add_zoom(40.0 * delta)
		if Input.is_action_pressed("zoom_out"):
			_add_zoom(-40.0 * delta)
	camera.fov = lerp(camera.fov, _base_fov() - zoom, min(1.0, delta * 12.0))
	# 기계 앞 시점: 렌더 프레임마다 부드럽게 따라간다(물리 틱에 묶이면 화면이 떨린다)
	if mode == Mode.MACHINE and machine and (_cam_tween == null or not _cam_tween.is_running()):
		var base_xf: Transform3D = _view_cams()[view_index].global_transform
		var rot := Basis(Vector3.UP, _look_off.x) * Basis(base_xf.basis.x.normalized(), _look_off.y)
		var xf := Transform3D(rot * base_xf.basis, base_xf.origin)
		camera.global_transform = camera.global_transform.interpolate_with(xf, 1.0 - exp(-delta * 30.0))


func _physics_process(delta: float) -> void:
	match mode:
		Mode.WALK:
			_walk(delta)
			_update_focus()
		Mode.MACHINE:
			_machine_controls(delta)
		Mode.UI:
			velocity = Vector3.ZERO


func _walk(delta: float) -> void:
	var dir := Vector3.ZERO
	if not ui_open:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y))
		dir.y = 0
		dir = dir.normalized() * min(iv.length(), 1.0)
	var sp := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	var target := dir * sp
	velocity.x = move_toward(velocity.x, target.x, 18.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= 9.81 * delta
	else:
		velocity.y = 0
	move_and_slide()
	# 발소리 & 머리 흔들림
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.3 and is_on_floor():
		_step_t += delta * hs * 1.9
		head.position.y = 1.62 + sin(_step_t * PI) * 0.018
		if _step_t >= 1.0:
			_step_t -= 1.0
			_step_i = (_step_i + 1) % 3
			Sfx.play("step%d" % _step_i, -16.0, randf_range(0.9, 1.1))
	else:
		head.position.y = lerp(head.position.y, 1.62, delta * 8.0)


func _update_focus() -> void:
	var f = null
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_meta("interactable"):
			f = c.get_meta("interactable")
	if f != focus:
		focus = f
		focus_changed.emit(focus)
	if focus and Input.is_action_just_pressed("interact") and not ui_open:
		_interact(focus)


func _interact(target) -> void:
	if target is ClawMachine:
		enter_machine(target)
	elif target.has_method("interact"):
		target.interact(self)


# ------------------------------------------------------------------ 기계 플레이
func enter_machine(m: ClawMachine) -> void:
	machine = m
	m.player_present = true
	mode = Mode.MACHINE
	view_index = 0
	zoom = 0.0
	_look_off = Vector2.ZERO
	velocity = Vector3.ZERO
	mode_changed.emit(mode)
	_move_camera_to(m.front_cam.global_transform)


func leave_machine() -> void:
	if machine:
		machine.set_input(Vector2.ZERO)
		machine.player_present = false
		machine.save_layout()
		# 기계 정면에 서 있도록 위치 이동
		var front: Vector3 = machine.to_global(Vector3(0, 0, machine.D * 0.5 + 0.75))
		global_position = Vector3(front.x, global_position.y, front.z)
		var to_m: Vector3 = machine.global_position - global_position
		_yaw = atan2(-to_m.x, -to_m.z)
		rotation.y = _yaw
		_pitch = -0.1
		head.rotation.x = _pitch
	machine = null
	mode = Mode.WALK
	mode_changed.emit(mode)
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(camera, "transform", Transform3D(), 0.35).set_trans(Tween.TRANS_SINE)
	zoom = 0.0


func _move_camera_to(xf: Transform3D) -> void:
	if _cam_tween:
		_cam_tween.kill()
	var local := head.global_transform.affine_inverse() * xf
	_cam_tween = create_tween()
	_cam_tween.tween_property(camera, "transform", local, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func cycle_view() -> void:
	if machine == null:
		return
	view_index = (view_index + 1) % 4
	_look_off = Vector2.ZERO
	_move_camera_to(_view_cams()[view_index].global_transform)


func _view_cams() -> Array:
	return [machine.front_cam, machine.side_cam, machine.side_cam_l, machine.close_cam]


func _machine_controls(_delta: float) -> void:
	if machine == null:
		return
	if ui_open:
		machine.set_input(Vector2.ZERO)
		return
	# 조이스틱: 앞(W/↑) = 기계 안쪽(-Z), 오른쪽 = +X  (옆에서 볼 때도 조이스틱 방향은 그대로)
	var x := Input.get_axis("move_left", "move_right")
	var y := Input.get_axis("move_forward", "move_back")
	machine.set_input(Vector2(x, y))
	# 2버튼 기계도 WASD로 조작: D/→ = ①(오른쪽), W/↑ = ②(안쪽, 떼면 하강). X/Space 도 그대로 동작
	var b1 := Input.is_action_pressed("button2") or Input.is_action_pressed("move_right")
	var b2 := Input.is_action_pressed("claw_drop") or Input.is_action_pressed("move_forward")
	machine.set_buttons(b1, b2)
	if Input.is_action_just_pressed("claw_drop"):
		machine.press_drop()
	if Input.is_action_just_pressed("insert_1000"):
		machine.insert_bill("1000")
	if Input.is_action_just_pressed("insert_5000"):
		machine.insert_bill("5000")
	if Input.is_action_just_pressed("toggle_view"):
		cycle_view()
	if Input.is_action_just_pressed("interact"):
		var got: Array = machine.take_prizes_from_bin()
		if got.is_empty():
			Game.say("배출구가 비어 있어요")  # 같은 알림은 HUD에서 하나로 합쳐진다
		else:
			var names := []
			for g in got:
				names.append(PrizeCatalog.display_name(g["id"]))
			Game.say("🧸 %s 을(를) 꺼냈어요! 전시장에 진열됩니다" % ", ".join(names))
	if Input.is_action_just_pressed("leave"):
		leave_machine()
		return


func set_ui_open(v: bool) -> void:
	ui_open = v
	if v:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
