class_name TouchControls
extends Control
## 휴대폰(아이폰) 터치 조작 – 최대한 단순하게.
## 걷기: 왼쪽 아래 아무 데나 대고 밀면 이동(끝까지 밀면 달리기) · 오른쪽을 밀면 둘러보기 · 두 손가락 = 확대
##       기계·자판기 등을 '톡' 누르면 바로 사용. 바라보고 있으면 오른쪽 아래에 큰 버튼 하나(뭘 하는지 글자로)
## 기계: 왼쪽 = 집게 이동, 오른쪽 큰 버튼 하나가 상황에 따라 [1,000원 넣기 → 내리기 → 꺼내기] 로 바뀐다
##       2버튼 기계는 이동할 때만 ① ② 두 버튼
## 위 가운데: 메뉴 버튼 하나(도움말·수집함·사장 모드·소리·저장은 메뉴 안)
## 버튼은 키보드와 같은 입력 동작(InputMap 액션)을 눌렀다 떼므로 게임 코드는 PC와 똑같이 동작한다.

var hud: HUD
var player: Player

const JOY_R := 92.0          # 조이스틱 반지름(기준 화면 1280x720 단위)
const LOOK_SENS := 0.0062    # 드래그 1단위당 회전(라디안)
const TAP_MOVE := 16.0       # 이만큼 안 움직이고 뗀 짧은 터치 = '톡'
const TAP_TIME := 0.35

var _ctx := ""
var _buttons: Array = []     # {id, text, action, pos, r, big, enabled}
var _held := {}              # id → 누르고 있는 손가락 번호
var _touches := {}           # 손가락 번호 → {role, id, start, t}
var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO
var _look_last := {}         # 손가락 번호 → 마지막 위치
var _pinch_d := -1.0
var _font: Font
var _safe := Rect2()
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Jua-Regular.ttf")


# ------------------------------------------------------------------ 상황 판단 + 배치
func _context() -> String:
	if hud == null or player == null:
		return ""
	if hud.inspector and hud.inspector.visible:
		return "inspector"
	if hud.help_panel.visible or hud.pause_panel.visible or hud.collection_panel.visible or hud.owner_panel.visible:
		return ""
	if player.mode == Player.Mode.MACHINE and player.machine:
		if String(player.machine.settings.get("control_mode", "joystick")) == "2button":
			return "machine2"
		return "machine"
	if player.mode == Player.Mode.WALK:
		return "walk"
	return ""


func _safe_rect() -> Rect2:
	# 노치·다이내믹 아일랜드·홈 바를 피한다(앱·웹 모두)
	return Game.safe_rect(get_viewport_rect().size)


## 바라보는 물건에 맞는 큰 버튼 글자
func _focus_label(f) -> String:
	if f == null:
		return ""
	if f is ClawMachine:
		return "뽑기 시작"
	if f is VendingMachine:
		return "음료 사기"
	if f is BillChanger:
		return "지폐 교환"
	if f is GachaMachine:
		return "캡슐 뽑기"
	if f is OwnerCounter:
		return "사장 모드"
	if f is ShowcaseSlot:
		return "자세히 보기"
	return "누르기"


## 지폐를 고를 때인가(쉬는 중 · 크레딧 없음 · 배출구 비었음)
func _choose_bill(m: ClawMachine) -> bool:
	return m.state == ClawMachine.State.IDLE and m.credits == 0 and m.prizes_in_bin().is_empty() \
		and (Game.has_bill("1000") or Game.has_bill("5000") or Game.has_bill("10000"))


## 기계 앞 큰 버튼: [글자, 동작(빈 문자열 = 기다리기)]
func _machine_main(m: ClawMachine) -> Array:
	if not m.prizes_in_bin().is_empty() and m.state != ClawMachine.State.MOVING:
		return ["꺼내기", "interact"]
	if m.state == ClawMachine.State.IDLE and m.credits == 0:
		return ["돈 없음", ""]
	if m.state == ClawMachine.State.MOVING:
		if m.drop_requested:
			return ["내려가요", ""]
		return ["내리기", "claw_drop"]
	if m.state == ClawMachine.State.IDLE:
		return ["조이스틱을\n움직여 시작", ""]
	return ["기다려요", ""]


func _layout() -> void:
	_safe = _safe_rect()
	var L := _safe.position.x + 26.0
	var R := _safe.end.x - 26.0
	var B := _safe.end.y - 22.0
	var cx := _safe.get_center().x
	_buttons.clear()
	if _ctx in ["walk", "machine", "machine2"]:
		_add("menu", "메뉴", "menu", Vector2(cx, _safe.position.y + 38.0), 32.0)
	match _ctx:
		"walk":
			var lab := _focus_label(player.focus)
			if lab != "":
				_add("interact", lab, "interact", Vector2(R - 96, B - 104), 78.0, true)
			_add("jump", "점프", "jump", Vector2(R - 96 if lab == "" else R - 262, B - 60), 44.0)
		"machine", "machine2":
			var m: ClawMachine = player.machine
			# 2버튼 기계: 크레딧이 있으면 ① 버튼이 곧 시작 버튼
			var two_ready := m.state == ClawMachine.State.IDLE and m.credits > 0 and m.prizes_in_bin().is_empty()
			var two_moving := _ctx == "machine2" and ((m.state == ClawMachine.State.MOVING and not m.drop_requested) or two_ready)
			if two_moving:
				# 2버튼 기계: ① 누르는 동안 오른쪽, ② 누르는 동안 안쪽(떼면 내려감)
				_add("b1", "① →", "button2", Vector2(R - 270, B - 92), 74.0, true, not m.btn1_used)
				_add("b2", "② ↑", "move_forward", Vector2(R - 96, B - 92), 74.0, true)
			elif _choose_bill(m):
				# 돈 넣기: 넣을 지폐를 고른다(가진 장수 표시)
				var big5 := bool(m.settings.get("accept_5000", true))
				_add("bill1", "1,000원\n×%d" % int(Game.wallet.get("1000", 0)), "insert_1000", Vector2(R - 100, B - 104), 74.0, true, Game.has_bill("1000"))
				_add("bill5", "5,000원\n×%d" % int(Game.wallet.get("5000", 0)), "insert_5000", Vector2(R - 262, B - 70), 54.0, true, big5 and Game.has_bill("5000"))
				_add("bill10", "10,000원\n×%d" % int(Game.wallet.get("10000", 0)), "insert_10000", Vector2(R - 110, B - 270), 54.0, true, big5 and Game.has_bill("10000"))
			else:
				var mm := _machine_main(m)
				_add("main", mm[0], mm[1], Vector2(R - 100, B - 104), 82.0, true, mm[1] != "")
			_add("view", "시점", "toggle_view", Vector2(R - 262, B - 230), 36.0)
			_add("leave", "나가기", "leave", Vector2(R - 60, B - 400), 34.0)
		"inspector":
			_add("zin", "+", "zoom_in", Vector2(R - 50, B - 170), 38.0)
			_add("zout", "-", "zoom_out", Vector2(R - 50, B - 70), 38.0)


func _add(id: String, text: String, action: String, pos: Vector2, r: float, big := false, enabled := true) -> void:
	_buttons.append({"id": id, "text": text, "action": action, "pos": pos, "r": r, "big": big, "enabled": enabled and action != ""})


func _joystick_allowed() -> bool:
	return _ctx == "walk" or _ctx == "machine"


func _process(delta: float) -> void:
	_time += delta
	var c := _context()
	if c != _ctx:
		_release_all()
		_ctx = c
	_layout()
	# 눌린 버튼이 상황이 바뀌어 사라지면(예: 내리기 → 기다려요) 그 동작을 뗀다
	for id in _held.keys():
		var still := false
		for b in _buttons:
			if b["id"] == id:
				still = true
		if not still:
			_release_button_action(id)
			_held.erase(id)
	queue_redraw()


var _held_actions := {}  # id → 누른 동작 이름(버튼 글자가 바뀌어도 정확히 떼기 위해)


func _release_button_action(id: String) -> void:
	var a: String = _held_actions.get(id, "")
	if a != "" and Input.is_action_pressed(a):
		Input.action_release(a)
	_held_actions.erase(id)


func _release_all() -> void:
	for id in _held_actions.keys():
		_release_button_action(id)
	for a in ["move_left", "move_right", "move_forward", "move_back", "run"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
	_held.clear()
	_held_actions.clear()
	_touches.clear()
	_look_last.clear()
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	_pinch_d = -1.0


func _buzz() -> void:
	if Game.phone:
		Input.vibrate_handheld(12, 0.35)


# ------------------------------------------------------------------ 터치 처리
func _input(event: InputEvent) -> void:
	if _ctx == "":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position, event.relative)


func _button_at(p: Vector2) -> Dictionary:
	for b in _buttons:
		if p.distance_to(b["pos"]) <= float(b["r"]) + 12.0:
			return b
	return {}


func _touch_down(i: int, p: Vector2) -> void:
	if _touches.has(i):
		_end_touch(i)  # 같은 번호가 아직 남아 있으면(떼는 신호를 놓친 경우) 먼저 정리
	var b := _button_at(p)
	if not b.is_empty():
		_touches[i] = {"role": "btn", "id": b["id"]}
		if b["enabled"]:
			_held[b["id"]] = i
			_held_actions[b["id"]] = b["action"]
			Input.action_press(b["action"])
			_buzz()
		get_viewport().set_input_as_handled()
		return
	var vs := get_viewport_rect().size
	if _joystick_allowed() and _joy_index < 0 and p.x < vs.x * 0.45 and p.y > vs.y * 0.28:
		_joy_index = i
		# 손가락을 댄 자리가 조이스틱 중심(화면 밖으로 나가지 않게)
		_joy_center = Vector2(clampf(p.x, _safe.position.x + JOY_R, vs.x * 0.45), clampf(p.y, vs.y * 0.28, _safe.end.y - JOY_R))
		_touches[i] = {"role": "joy", "start": p, "t": _time, "moved": 0.0}
		_update_joy(p)
		get_viewport().set_input_as_handled()
		return
	if _ctx == "inspector":
		return  # 상품 보기 화면: 드래그는 상품 돌리기(가운데 3D 창)에 맡긴다
	_touches[i] = {"role": "look", "start": p, "t": _time, "moved": 0.0}
	_look_last[i] = p
	_pinch_d = -1.0


## 손을 뗀 것으로 정리만 한다(톡 판정 없이)
func _end_touch(i: int) -> void:
	var t: Dictionary = _touches[i]
	_touches.erase(i)
	match String(t["role"]):
		"btn":
			var id: String = t["id"]
			if _held.get(id, -1) == i:
				_held.erase(id)
				_release_button_action(id)
		"joy":
			_joy_index = -1
			_joy_vec = Vector2.ZERO
			_apply_joy()
		"look":
			_look_last.erase(i)
			_pinch_d = -1.0


func _touch_up(i: int, p: Vector2) -> void:
	if not _touches.has(i):
		return
	var t: Dictionary = _touches[i]
	_touches.erase(i)
	match String(t["role"]):
		"btn":
			var id: String = t["id"]
			if _held.get(id, -1) == i:
				_held.erase(id)
				_release_button_action(id)
		"joy":
			_joy_index = -1
			_joy_vec = Vector2.ZERO
			_apply_joy()
			# 왼쪽 아래도 짧게 톡 누르면 그 자리 물건 사용
			if float(t["moved"]) < TAP_MOVE and _time - float(t["t"]) < TAP_TIME:
				_tap_world(p)
		"look":
			var was_pinch := _look_last.size() >= 2
			_look_last.erase(i)
			_pinch_d = -1.0
			# 짧게 '톡' → 그 자리에 있는 기계·자판기 등을 바로 사용
			if not was_pinch and float(t["moved"]) < TAP_MOVE and _time - float(t["t"]) < TAP_TIME:
				_tap_world(p)


func _touch_move(i: int, p: Vector2, rel: Vector2) -> void:
	if not _touches.has(i):
		return
	var t: Dictionary = _touches[i]
	match String(t["role"]):
		"joy":
			t["moved"] = maxf(float(t["moved"]), p.distance_to(t["start"]))
			_update_joy(p)
		"look":
			t["moved"] = maxf(float(t["moved"]), p.distance_to(t["start"]))
			# 움직인 양은 손가락마다 직접 계산한다(웹은 손가락 두 개일 때 엔진이 주는 relative 가 서로 섞이는 문제가 있음)
			var prev: Vector2 = _look_last.get(i, p)
			rel = p - prev
			if rel.length() > 160.0:
				rel = Vector2.ZERO  # 순간 튀는 값은 무시
			_look_last[i] = p
			if _look_last.size() >= 2:
				# 두 손가락: 벌리면 확대, 오므리면 축소
				var pts: Array = _look_last.values()
				var d: float = (pts[0] as Vector2).distance_to(pts[1])
				if _pinch_d > 0.0 and player:
					player.add_zoom((d - _pinch_d) * 0.08)
				_pinch_d = d
			elif player:
				var s := LOOK_SENS * (Game.mouse_sensitivity / 0.0022)
				player.look(rel * s)


## 화면을 톡 누른 곳의 물건 사용(걷는 중에만)
func _tap_world(p: Vector2) -> void:
	if _ctx != "walk" or player == null or player.ui_open:
		return
	var cam := player.camera
	var from := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 3.2, 16)
	q.collide_with_areas = true
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var c: Object = hit["collider"]
	if c == null or not c.has_meta("interactable"):
		return
	var target = c.get_meta("interactable")
	_buzz()
	if target.has_method("interact_tap"):
		target.interact_tap(player, from, dir)
	else:
		player._interact(target)


func _update_joy(p: Vector2) -> void:
	var off := p - _joy_center
	if off.length() > JOY_R:
		# 손가락이 멀리 가면 조이스틱도 따라온다
		_joy_center = p - off.normalized() * JOY_R
		off = p - _joy_center
	var v := off / JOY_R
	_joy_vec = v if v.length() > 0.12 else Vector2.ZERO
	_apply_joy()


func _apply_joy() -> void:
	var v := _joy_vec.limit_length(1.0)
	_axis("move_right", maxf(v.x, 0.0))
	_axis("move_left", maxf(-v.x, 0.0))
	_axis("move_back", maxf(v.y, 0.0))
	_axis("move_forward", maxf(-v.y, 0.0))
	# 걷기: 끝까지 밀면 달리기
	var run := _ctx == "walk" and v.length() > 0.93
	if run and not Input.is_action_pressed("run"):
		Input.action_press("run")
	elif not run and Input.is_action_pressed("run"):
		Input.action_release("run")


func _axis(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		# 2버튼 기계의 ② 버튼이 move_forward 를 쓰고 있을 수 있으므로, 버튼이 눌린 동안은 떼지 않는다
		if action == "move_forward" and _held.has("b2"):
			return
		Input.action_release(action)


# ------------------------------------------------------------------ 그리기
func _draw() -> void:
	if _ctx == "":
		return
	if _joystick_allowed():
		var c := _joy_center if _joy_index >= 0 else Vector2(_safe.position.x + 150.0, _safe.end.y - 150.0)
		var a := 0.55 if _joy_index >= 0 else 0.3
		draw_circle(c, JOY_R, Color(0.1, 0.05, 0.15, a * 0.6))
		draw_arc(c, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, a), 3.0, true)
		draw_circle(c + _joy_vec.limit_length(1.0) * JOY_R, 40.0, Color(1.0, 0.55, 0.78, a + 0.25))
		if _joy_index < 0:
			_text(c + Vector2(0, JOY_R + 22), "이동" if _ctx == "walk" else "집게 이동", 20, Color(1, 1, 1, 0.8))
	for b in _buttons:
		var on: bool = _held.has(b["id"])
		var r: float = b["r"]
		var en: bool = b["enabled"]
		var base := Color(0.95, 0.35, 0.62) if b["big"] else Color(0.12, 0.08, 0.18)
		if not en:
			base = Color(0.35, 0.33, 0.4)
		var alpha := 0.9 if on else (0.72 if b["big"] else 0.5)
		if not en:
			alpha = 0.45
		# 큰 버튼은 숨 쉬듯 살짝 커졌다 작아져서 '여기 누르세요'를 알려 준다
		if b["big"] and en and not on:
			r += sin(_time * 4.0) * 3.0
		draw_circle(b["pos"], r, Color(base.r, base.g, base.b, alpha))
		draw_arc(b["pos"], r, 0.0, TAU, 48, Color(1, 1, 1, 0.95 if on else (0.7 if en else 0.3)), 3.0 if on else 2.0, true)
		var lines: PackedStringArray = String(b["text"]).split("\n")
		var fs := int(clampf(float(b["r"]) * (0.3 if lines.size() > 1 else 0.36), 16.0, 30.0))
		for li in lines.size():
			var oy := (li - (lines.size() - 1) * 0.5) * fs * 1.15
			_text(b["pos"] + Vector2(0, oy), lines[li], fs, Color(1, 1, 1, 1.0 if en else 0.7))


func _text(c: Vector2, t: String, size: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := _font.get_ascent(size)
	var desc := _font.get_descent(size)
	var pos := c + Vector2(-w * 0.5, (asc - desc) * 0.5)
	draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.15, 0.05, 0.15, 0.8))
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
