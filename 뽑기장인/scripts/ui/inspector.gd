class_name Inspector
extends Control
## 전시장 인형 확대 보기: 마우스로 끌어서 돌리고, 휠/+/- 로 확대·축소, ◀ ▶ 로 다른 인형 보기

var hud
var viewport: SubViewport
var container: SubViewportContainer
var pivot: Node3D
var cam: Camera3D
var model: Prize
var title_label: Label
var info_label: Label
var index := 0
var _yaw := 0.4
var _pitch := -0.15
var _dist := 0.6
var _target_dist := 0.6
var _base_dist := 0.6
var _center := Vector3.ZERO
var _dragging := false
var _auto_spin := true
var opened_frame := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.05, 0.12, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -370
	panel.offset_bottom = 370
	if Game.touch:
		# 휴대폰 기준 화면(높이 720)에 들어가게
		panel.offset_top = -350
		panel.offset_bottom = 350
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	title_label = UIKit.title("", 30)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_label)
	top.add_child(UIKit.button("◀ 이전", func(): show_index(index - 1)))
	top.add_child(UIKit.button("다음 ▶", func(): show_index(index + 1)))
	top.add_child(UIKit.button("닫기" if Game.touch else "닫기 (Esc)", close, Color(0.6, 0.55, 0.62)))

	container = SubViewportContainer.new()
	# 크기 고정(stretch 끄기): 숨겨진 동안 0×0 크기 뷰포트가 생기지 않게 한다
	container.stretch = false
	var vh := 480 if Game.touch else 540
	container.custom_minimum_size = Vector2(1000, vh)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_view_input)
	v.add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = Vector2i(1000, vh)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(viewport)
	_build_studio()

	info_label = UIKit.label("", 19)
	v.add_child(info_label)
	v.add_child(UIKit.label("손가락으로 끌어서 돌리기 · 오른쪽 + / - 버튼으로 확대·축소 · ◀ ▶ 로 다른 인형" if Game.touch else "마우스 왼쪽 버튼으로 끌어서 돌리기 · 휠 또는 +/- 로 확대·축소 · ← → 키로 다른 인형 · R 처음 각도", 16, Color(0.45, 0.35, 0.45)))


func _build_studio() -> void:
	var root := Node3D.new()
	viewport.add_child(root)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(1.0, 0.93, 0.96)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.97, 1.0)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	we.environment = e
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 35, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(1.0, 0.85, 0.95)
	root.add_child(rim)
	# 받침대
	var stand := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.32
	cm.height = 0.03
	cm.radial_segments = 48
	stand.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 0.8, 0.88)
	sm.roughness = 0.4
	stand.material_override = sm
	stand.position.y = -0.016
	root.add_child(stand)
	pivot = Node3D.new()
	root.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 35
	cam.near = 0.01
	root.add_child(cam)


func open_entry(i: int) -> void:
	if Game.collection.is_empty():
		Game.say("아직 뽑은 인형이 없어요")
		return
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	opened_frame = Engine.get_process_frames()
	if hud and hud.player:
		hud.player.set_ui_open(true)
	show_index(i)


func close() -> void:
	visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if model:
		model.queue_free()
		model = null
	if hud and hud.player:
		hud.player.set_ui_open(false)


func show_index(i: int) -> void:
	var n := Game.collection.size()
	if n == 0:
		return
	index = wrapi(i, 0, n)
	var e: Dictionary = Game.collection[index]
	if model:
		model.queue_free()
	model = PrizeFactory.create(e["id"], null, int(e.get("colorway", 0)))
	for b in model.bodies:
		b.freeze = true
		b.collision_layer = 0
		b.collision_mask = 0
	pivot.add_child(model)
	# 모델 크기에 맞춰 가운데 정렬·거리 설정
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = _local_xf(mi) * mi.get_aabb()
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	_center = box.get_center()
	model.position = Vector3(-_center.x, -box.position.y, -_center.z)
	var size := box.size.length()
	_base_dist = max(size * 1.6, 0.18)
	_dist = _base_dist
	_target_dist = _base_dist
	_center = Vector3(0, box.size.y * 0.5, 0)
	_yaw = 0.5
	_pitch = -0.18
	_auto_spin = true
	var item := PrizeCatalog.get_item(e["id"])
	title_label.text = "%s  (%d / %d)" % [item.get("name", e["id"]), index + 1, n]
	var spent := int(e.get("spent", 0))
	info_label.text = "획득: %s   ·   이 인형에 쓴 돈: %s   ·   가게 원가: %s   ·   뽑은 곳: %s" % [
		String(e.get("time", "")).replace("T", " ").substr(0, 16), Game.won(spent) if spent > 0 else "-",
		Game.won(int(item.get("cost", 0))), _machine_name(String(e.get("machine", "")))]


func _machine_name(id: String) -> String:
	if id == "gacha":
		return "캡슐뽑기"
	var s: Dictionary = Game.machine_settings.get(id, {})
	return String(s.get("name", id))


func _local_xf(n: Node3D) -> Transform3D:
	var t := Transform3D()
	var p: Node = n
	while p != null and p != model and p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_auto_spin = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(1.14)
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.01
		_pitch = clamp(_pitch - event.relative.y * 0.008, -1.3, 1.3)


func _zoom(f: float) -> void:
	_target_dist = clamp(_target_dist * f, _base_dist * 0.25, _base_dist * 2.5)


func _process(delta: float) -> void:
	if not visible:
		return
	if Input.is_action_pressed("zoom_in"):
		_zoom(1.0 - delta * 1.5)
	if Input.is_action_pressed("zoom_out"):
		_zoom(1.0 + delta * 1.5)
	if Input.is_action_just_pressed("move_left"):
		show_index(index - 1)
	if Input.is_action_just_pressed("move_right"):
		show_index(index + 1)
	if Input.is_key_pressed(KEY_R):
		_yaw = 0.5
		_pitch = -0.18
		_target_dist = _base_dist
	if _auto_spin:
		_yaw += delta * 0.4
	_dist = lerp(_dist, _target_dist, min(1.0, delta * 10.0))
	var dir := Vector3(sin(_yaw) * cos(_pitch), -sin(_pitch), cos(_yaw) * cos(_pitch))
	cam.look_at_from_position(_center + dir * _dist, _center)
