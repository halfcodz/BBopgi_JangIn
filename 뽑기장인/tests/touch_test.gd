extends SceneTree
## 휴대폰 터치 조작 검증(가짜 손가락 입력). 실행:
## BBOPGI_TOUCH=1 godot --headless --fixed-fps 120 -s tests/touch_test.gd
## 걷기(조이스틱) · 둘러보기 · 두 손가락 확대 · 기계 버튼(돈 넣기·이동·내리기·나가기) · 2버튼 기계 · 메뉴

var tc
var fails := 0


## 게임 화면 좌표 → 창(손가락) 좌표. 웹처럼 가로 고정(돌려 그리기) 중이면 그 변환을 거꾸로 따라간다
func _xf() -> Transform2D:
	var h = get_root().get_node_or_null("Game/LandscapeHost")
	if h:
		var k: Vector2 = Vector2(h.vp.size) / Vector2(h.vp.size_2d_override)
		return h.container.get_global_transform() * Transform2D(0.0, k, 0.0, Vector2.ZERO)
	return get_root().get_final_transform()


func _to_win(p: Vector2) -> Vector2:
	return _xf() * p


func _down(i: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _to_win(p)
	e.pressed = true
	Input.parse_input_event(e)


func _up(i: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _to_win(p)
	e.pressed = false
	Input.parse_input_event(e)


func _drag(i: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = _to_win(p)
	# 웹 엔진처럼 일부러 엉뚱한 relative 를 넣어도 조작은 손가락 위치로 계산되어야 한다
	e.relative = _xf().basis_xform(rel) if OS.get_environment("BAD_REL") != "1" else Vector2(517, -333)
	Input.parse_input_event(e)


func _btn(id: String) -> Vector2:
	for b in tc._buttons:
		if b["id"] == id:
			return b["pos"]
	printerr("  (버튼 없음: ", id, " 상황=", tc._ctx, ")")
	return Vector2(-999, -999)


func _tap(id: String, hold := 3) -> void:
	var p := _btn(id)
	_down(5, p)
	for k in hold:
		await physics_frame
	await process_frame
	_up(5, p)
	for k in 3:
		await physics_frame
	await process_frame


func _check(name: String, ok: bool, info := "") -> void:
	if not ok:
		fails += 1
	printerr(("  OK  " if ok else "  실패 ") + name + ("  " + info if info != "" else ""))


func _frames(n: int) -> void:
	for k in n:
		await physics_frame


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await _frames(240)
	var game = get_root().get_node("/root/Game")
	_check("터치 모드 켜짐", game.touch)
	var host = get_root().get_node_or_null("Game/LandscapeHost")
	if host:
		printerr("  (가로 고정 화면: 돌려 그리기=", host.rotated, ", 게임 화면=", host.vp.size_2d_override, ")")
	tc = main.hud.touch_controls
	_check("터치 조작 화면 있음", tc != null)
	if tc == null:
		quit(1)
		return
	game.give_money("1000", 10)
	var player = main.player
	player.global_position = Vector3(2.2, 0.05, 4.0)
	await _frames(10)
	_check("걷기 상황", tc._ctx == "walk", tc._ctx)
	# 1) 조이스틱으로 앞으로 걷기
	var p0: Vector3 = player.global_position
	var vs: Vector2 = tc.get_viewport_rect().size
	var jp := Vector2(200, vs.y - 170)
	_down(0, jp)
	await process_frame
	_drag(0, jp + Vector2(0, -80), Vector2(0, -80))
	await _frames(90)
	_up(0, jp + Vector2(0, -80))
	await _frames(20)
	var moved: float = Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	_check("조이스틱으로 걷기", moved > 0.8, "%.2fm" % moved)
	_check("손 떼면 멈춤", not Input.is_action_pressed("move_forward"))
	# 끝까지 밀면 달리기
	_down(0, jp)
	await process_frame
	_drag(0, jp + Vector2(0, -120), Vector2(0, -120))
	await _frames(5)
	_check("끝까지 밀면 달리기", Input.is_action_pressed("run"))
	_up(0, jp + Vector2(0, -120))
	await _frames(5)
	_check("떼면 달리기 끝", not Input.is_action_pressed("run"))
	# 2) 오른쪽 드래그로 둘러보기
	var yaw0: float = player._yaw
	var lp := Vector2(vs.x * 0.6, vs.y * 0.45)
	_down(1, lp)
	await process_frame
	for k in 10:
		_drag(1, lp + Vector2(10 * (k + 1), 0), Vector2(10, 0))
		await process_frame
	_up(1, lp + Vector2(100, 0))
	_check("드래그로 고개 돌리기", absf(player._yaw - yaw0) > 0.3, "%.2f rad" % (player._yaw - yaw0))
	# 2-1) 걸으면서 동시에 둘러보기(왼손 조이스틱 + 오른손 드래그)
	var both_p0: Vector3 = player.global_position
	var both_yaw0: float = player._yaw
	_down(0, jp)
	await process_frame
	_drag(0, jp + Vector2(0, -80), Vector2(0, -80))
	_down(1, lp)
	for k in 30:
		_drag(1, lp + Vector2(4 * (k + 1), 0), Vector2(4, 0))
		await physics_frame
		await process_frame
	var both_moved: float = Vector2(player.global_position.x - both_p0.x, player.global_position.z - both_p0.z).length()
	var both_turn: float = absf(player._yaw - both_yaw0)
	_up(1, lp + Vector2(120, 0))
	_up(0, jp + Vector2(0, -80))
	await _frames(10)
	_check("걸으면서 동시에 둘러보기", both_moved > 0.2 and both_turn > 0.3 and both_turn < 2.0, "%.2fm, %.2f rad" % [both_moved, both_turn])
	_check("동시 조작 뒤 눌림 없음", not Input.is_action_pressed("move_forward"))
	# 3) 두 손가락 확대
	var z0: float = player.zoom
	_down(1, Vector2(vs.x * 0.55, 300))
	_down(2, Vector2(vs.x * 0.65, 300))
	await process_frame
	for k in 8:
		_drag(2, Vector2(vs.x * 0.65 + 12 * (k + 1), 300), Vector2(12, 0))
		await process_frame
	_up(1, Vector2(vs.x * 0.55, 300))
	_up(2, Vector2(vs.x * 0.65 + 96, 300))
	_check("두 손가락 확대", player.zoom > z0 + 3.0, "%.1f°" % (player.zoom - z0))
	player.zoom = 0.0
	# 4) 점프
	await _frames(10)
	var y0: float = player.global_position.y
	_down(3, _btn("jump"))
	var top := y0
	for k in 30:
		await physics_frame
		top = maxf(top, player.global_position.y)
	_up(3, _btn("jump"))
	_check("점프 버튼", top > y0 + 0.2, "%.2fm" % (top - y0))
	await _frames(60)
	# 6) 기계 앞에서 '누르기' → 기계 플레이
	var m = main.shop.machines[0]
	var front: Vector3 = m.to_global(Vector3(0, 0, m.D * 0.5 + 0.7))
	player.global_position = Vector3(front.x, 0.05, front.z)
	var to_m: Vector3 = m.global_position - player.global_position
	player._yaw = atan2(-to_m.x, -to_m.z)
	player.rotation.y = player._yaw
	player._pitch = -0.25
	player.head.rotation.x = -0.25
	await _frames(20)
	_check("기계를 바라봄", player.focus == m)
	var big := false
	for b in tc._buttons:
		if b["id"] == "interact" and b["text"] == "뽑기 시작":
			big = true
	_check("바라보면 '뽑기 시작' 큰 버튼", big)
	# 화면에서 기계를 직접 톡 누르기
	var sp: Vector2 = player.camera.unproject_position(m.to_global(Vector3(0, m.base_h + 0.4, m.D * 0.5)))
	_down(6, sp)
	await process_frame
	_up(6, sp)
	await _frames(30)
	_check("기계를 톡 → 기계 플레이", player.mode == player.Mode.MACHINE and tc._ctx == "machine", tc._ctx)
	var c0: int = m.credits
	_check("지폐 고르기 버튼(1,000/5,000/10,000)", tc._buttons.any(func(b): return b["id"] == "bill1") and tc._buttons.any(func(b): return b["id"] == "bill5") and tc._buttons.any(func(b): return b["id"] == "bill10"))
	await _tap("bill1")
	await _frames(240)
	_check("1,000원 넣기 → 크레딧만 쌓이고 기다림", m.credits > c0 and m.state == m.State.IDLE, "credit=%d state=%d" % [m.credits, m.state])
	# 조이스틱으로 집게 이동(움직이는 순간 게임 시작)
	var cx0: float = m.carriage.x
	_down(0, jp)
	await process_frame
	_drag(0, jp + Vector2(85, 0), Vector2(85, 0))
	await _frames(100)
	_check("조이스틱을 움직이면 시작", m.state == m.State.MOVING, "state=%d" % m.state)
	_check("큰 버튼 = 내리기", tc._buttons.any(func(b): return b["id"] == "main" and b["text"] == "내리기"))
	_up(0, jp + Vector2(85, 0))
	_check("조이스틱으로 집게 이동", m.carriage.x > cx0 + 0.05, "%.2fm" % (m.carriage.x - cx0))
	await _tap("view")
	_check("시점 버튼", player.view_index == 1)
	await _tap("main")
	await _frames(120)
	_check("내리기 버튼", m.state != m.State.MOVING and m.state != m.State.IDLE, "state=%d" % m.state)
	for k in 3000:
		await physics_frame
		if m.state == m.State.IDLE:
			break
	await _tap("leave")
	await _frames(30)
	_check("나가기 버튼", player.mode == player.Mode.WALK and tc._ctx == "walk")
	# 7) 2버튼 기계(일본식)
	var bm = null
	for mm in main.shop.machines:
		if String(mm.settings.get("control_mode", "")) == "2button":
			bm = mm
			break
	if bm:
		player.enter_machine(bm)
		await _frames(30)
		_check("2버튼 기계 상황", tc._ctx == "machine2", tc._ctx)
		await _tap("bill1")
		await _frames(240)
		_check("2버튼: 돈 넣으면 기다리고 ① 버튼 보임", bm.state == bm.State.IDLE and tc._buttons.any(func(b): return b["id"] == "b1"), "state=%d" % bm.state)
		var bx0: float = bm.carriage.x
		var bz0: float = bm.carriage.z
		_down(4, _btn("b1"))
		await _frames(120)
		_up(4, _btn("b1"))
		await _frames(30)
		_check("① 누르는 동안 오른쪽", bm.carriage.x > bx0 + 0.03, "%.2fm" % (bm.carriage.x - bx0))
		_down(4, _btn("b2"))
		await _frames(120)
		_up(4, _btn("b2"))
		await _frames(60)
		_check("② 누르는 동안 안쪽, 떼면 내려감", bm.carriage.z < bz0 - 0.03 and bm.state != bm.State.MOVING, "z %.2fm state=%d" % [bm.carriage.z - bz0, bm.state])
		for k in 3000:
			await physics_frame
			if bm.state == bm.State.IDLE:
				break
		player.leave_machine()
		await _frames(30)
	# 8) 메뉴·도움말·수집함 버튼
	await _tap("menu")
	await _frames(5)
	_check("메뉴 버튼", main.hud.pause_panel.visible and tc._ctx == "")
	main.hud._toggle_pause()
	await _frames(5)
	await _frames(5)
	_check("메뉴 닫으면 다시 조작", tc._ctx == "walk")
	# 음료 자판기: 진열창의 음료를 톡
	var vm = null
	for c in main.shop.get_children():
		if c.has_method("interact_tap"):
			vm = c
	player.global_position = vm.to_global(Vector3(0, 0, 1.0))
	player.global_position.y = 0.05
	var tv: Vector3 = vm.global_position - player.global_position
	player._yaw = atan2(-tv.x, -tv.z)
	player.rotation.y = player._yaw
	player._pitch = -0.05
	player.head.rotation.x = -0.05
	await _frames(10)
	var w0 := int(game.wallet.get("1000", 0))
	var slot = vm._slots[0]
	var tp: Vector2 = player.camera.unproject_position(vm.to_global(slot["pos"] + Vector3(0, 0.06, 0)))
	var hit_dbg = player.camera.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.project_ray_origin(tp), player.camera.project_ray_origin(tp) + player.camera.project_ray_normal(tp) * 3.2, 16))
	printerr("  (자판기 톡 위치 ", tp, " 화면 ", tc.get_viewport_rect().size, " 맞은 것 ", hit_dbg.get("collider"), " 지갑 ", w0, " ctx ", tc._ctx, ")")
	_down(6, tp)
	await process_frame
	_up(6, tp)
	await _frames(200)
	_check("자판기 음료를 톡 → 구매", w0 - int(game.wallet.get("1000", 0)) == 1 and vm._in_port == slot["drink"], "port=%d" % vm._in_port)
	_check("남은 눌림 없음", not Input.is_action_pressed("move_forward") and not Input.is_action_pressed("run") and not Input.is_action_pressed("interact"))
	printerr("터치 테스트 결과: 실패 %d" % fails)
	quit(1 if fails > 0 else 0)
