extends Node
## 전역 상태: 지갑, 기계 설정, 매출 장부, 획득한 상품(전시장), 저장/불러오기, 입력 키 등록

signal wallet_changed
signal collection_changed
signal owner_mode_changed(on: bool)
signal toast(text: String)
signal settings_changed(machine_id: String)

const SAVE_PATH := "user://bbopgi_save.json"

## 지갑: 권종별 개수
var wallet := {"10000": 3, "5000": 1, "1000": 10, "500": 4}
## 획득한 상품: [{id, colorway, machine, day, spent}]
var collection: Array = []
## 기계별 설정/장부
var machine_settings := {}
var ledgers := {}
## 플레이 통계(연습 기록)
var stats := {"plays": 0, "spent": 0, "wins": 0, "gacha": 0}
var owner_mode := false
var spent_since_last_win := 0
var bgm_volume := 0.6
var sfx_volume := 0.9
var mouse_sensitivity := 0.0022
## 게임 속도(1.0 = 보통, 2.0 = 두 배). 물리 계산 간격은 그대로 두고 1초에 계산하는 횟수를 늘려 똑같이 정확하게 빨라진다
var game_speed := 1.0
const BASE_TICKS := 120
var landscape_host: Node
## 터치(아이폰·아이패드 등) 조작 모드. PC에서 시험하려면 실행 인자 -- --touch
var touch := false
## 실제 휴대폰인가(시험용: 환경변수 BBOPGI_PHONE=1 이면 PC에서도 휴대폰처럼)
var phone := false
## 웹 브라우저(휴대폰 사파리)에서 도는 중인가(시험용: BBOPGI_WEB=1)
var web := false


func _ready() -> void:
	web = OS.has_feature("web") or OS.get_environment("BBOPGI_WEB") == "1"
	phone = OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android") \
		or OS.get_environment("BBOPGI_PHONE") == "1"
	touch = phone or OS.has_feature("ios") or OS.has_feature("android") \
		or OS.get_cmdline_user_args().has("--touch") or OS.get_environment("BBOPGI_TOUCH") == "1"
	_register_inputs()
	_setup_font_fallbacks()
	load_game()
	if touch:
		_setup_mobile()


## 한글 글꼴에 없는 기호(·, ①, →, 이모지 등)를 대신 그려 줄 글꼴.
## 웹(사파리)에는 시스템 글꼴 대체가 없어서 이게 없으면 네모(□)로 나온다
func _setup_font_fallbacks() -> void:
	var fb: Array[Font] = []
	for p in ["res://assets/fonts/FallbackSymbols.ttf", "res://assets/fonts/FallbackEmoji.ttf"]:
		var f = load(p)
		if f is Font:
			fb.append(f)
	for p in ["res://assets/fonts/Jua-Regular.ttf", "res://assets/fonts/BlackHanSans-Regular.ttf", "res://assets/fonts/DoHyeon-Regular.ttf"]:
		var main = load(p)
		if main is Font:
			(main as Font).fallbacks = fb
	var df := ThemeDB.fallback_font
	if df:
		df.fallbacks = fb


## 휴대폰용 화면·성능 설정
func _setup_mobile() -> void:
	var win := get_tree().root
	# 멀리 있는 인형·물건은 더 일찍 간단한 모양(LOD)으로 그린다(작은 화면에서는 차이가 안 보임)
	win.mesh_lod_threshold = 4.0
	# 기준 화면을 1280x720으로 → 휴대폰에서 글씨·버튼이 커진다(가로는 화면 비율에 맞춰 늘어남)
	win.content_scale_size = Vector2i(1280, 720)
	if phone:
		# 열·배터리: 화면은 60fps, 3D는 해상도를 조금 낮춰 그린다(글씨·UI는 원래 해상도)
		Engine.max_fps = 60
		win.scaling_3d_scale = 0.8
		Engine.max_physics_steps_per_frame = 4
	if web:
		# 휴대폰 웹(사파리): 그래픽 처리 여유가 적으므로 3D 해상도를 더 낮추고, 느려지면 물리를 늦춰 버틴다
		win.scaling_3d_scale = 1.0  # 화면 배율을 2배로 묶어 두었으므로(웹 시작 화면) 3D는 제 해상도로(중간 버퍼 없이 한 번에 그림)
		Engine.max_physics_steps_per_frame = 3
	# 웹(휴대폰 사파리): 화면 방향을 잠글 수 없으니 게임을 항상 가로로 돌려 그린다
	if web or OS.get_environment("BBOPGI_ROTATE") == "1":
		landscape_host = LandscapeHost.new()
		landscape_host.name = "LandscapeHost"
		add_child(landscape_host)  # 게임 장면보다 먼저 만들어 두어야 장면이 그 안에 만들어진다
	# 마우스가 없는 PC에서 시험할 때: 마우스로 터치를 흉내 낸다
	if not phone and not DisplayServer.is_touchscreen_available():
		Input.emulate_touch_from_mouse = true


## 게임 속도 바꾸기: 시간 배율과 1초당 물리 계산 횟수를 같이 올려 한 번 계산하는 간격(1/120초)은 그대로 유지
func set_game_speed(s: float) -> void:
	game_speed = clampf(snappedf(s, 0.1), 1.0, 2.0)
	Engine.time_scale = game_speed
	Engine.physics_ticks_per_second = int(round(BASE_TICKS * game_speed))
	var base_steps := 3 if web else (4 if phone else 12)
	Engine.max_physics_steps_per_frame = int(ceil(base_steps * game_speed))


var _web_safe := PackedFloat64Array()
var _web_safe_t := -1.0


## 화면에서 버튼·글씨를 둘 수 있는 안전 영역(노치·다이내믹 아일랜드·홈 바 피함), 게임 화면 단위(vs = 화면 크기)
## 3D 화면은 가장자리까지 꽉 채우고, 누르는 버튼과 안내판만 이 안쪽에 둔다
func safe_rect(vs: Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, vs)
	if web:
		if not OS.has_feature("web"):
			return full
		var now := Time.get_ticks_msec() / 1000.0
		if _web_safe_t < 0.0 or now - _web_safe_t > 0.5:
			_web_safe_t = now
			var s = JavaScriptBridge.eval("window.__bbSafe ? window.__bbSafe.join(',') : ''", true)
			if s is String and s != "":
				_web_safe = PackedFloat64Array(Array(s.split(",")).map(func(x): return float(x)))
		if _web_safe.size() < 6 or _web_safe[4] <= 0.0 or _web_safe[5] <= 0.0:
			return full
		var l := _web_safe[0]
		var t := _web_safe[1]
		var r := _web_safe[2]
		var b := _web_safe[3]
		var rot: bool = landscape_host != null and landscape_host.rotated
		var k := vs.y / (_web_safe[4] if rot else _web_safe[5])
		if rot:
			# 화면을 돌려 그릴 때: 게임 왼쪽=휴대폰 위, 게임 오른쪽=아래, 게임 위=오른쪽, 게임 아래=왼쪽
			var gl := t
			var gr := b
			var gt := r
			var gb := l
			l = gl; r = gr; t = gt; b = gb
		return Rect2(Vector2(l, t) * k, vs - Vector2(l + r, t + b) * k)
	if not phone:
		return full
	var win := Vector2(DisplayServer.window_get_size())
	var sa := DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or sa.size.x <= 0:
		return full
	var kk := vs / win
	return Rect2(Vector2(sa.position) * kk, Vector2(sa.size) * kk).intersection(full)


## 물리 한 번 계산하는 시간(초) – 게임 속도와 상관없이 1/120
func phys_dt() -> float:
	return Engine.time_scale / float(Engine.physics_ticks_per_second)


## 마우스 커서 잡기/풀기(터치 기기에는 마우스가 없으므로 건드리지 않는다)
func set_mouse_captured(on: bool) -> void:
	if touch:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ 입력
func _add_key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _register_inputs() -> void:
	_add_key("move_forward", [KEY_W, KEY_UP])
	_add_key("move_back", [KEY_S, KEY_DOWN])
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("run", [KEY_SHIFT])
	_add_key("jump", [KEY_SPACE])
	_add_key("crouch", [KEY_CTRL])
	_add_key("interact", [KEY_E])
	_add_key("claw_drop", [KEY_SPACE, KEY_ENTER])
	_add_key("insert_1000", [KEY_B])
	_add_key("insert_5000", [KEY_N])
	_add_key("toggle_view", [KEY_C])
	_add_key("leave", [KEY_Q])
	_add_key("menu", [KEY_ESCAPE])
	_add_key("zoom_in", [KEY_EQUAL, KEY_KP_ADD])
	_add_key("zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT])
	_add_key("owner_mode", [KEY_F1, KEY_TAB])
	_add_key("collection", [KEY_I])
	_add_key("help", [KEY_H])
	_add_key("button2", [KEY_X])
	_add_key("insert_10000", [KEY_M])
	_add_mouse("place_click", MOUSE_BUTTON_LEFT)
	_add_mouse("remove_click", MOUSE_BUTTON_RIGHT)


# ------------------------------------------------------------------ 지갑
func cash_total() -> int:
	var t := 0
	for k in wallet:
		t += int(k) * int(wallet[k])
	return t


func has_bill(kind: String) -> bool:
	return int(wallet.get(kind, 0)) > 0


func take_bill(kind: String) -> bool:
	if not has_bill(kind):
		return false
	wallet[kind] = int(wallet[kind]) - 1
	wallet_changed.emit()
	return true


func give_money(kind: String, count: int) -> void:
	wallet[kind] = int(wallet.get(kind, 0)) + count
	wallet_changed.emit()


## 지폐교환기: 큰 지폐를 1,000원권으로
func change_bill(kind: String) -> bool:
	if not take_bill(kind):
		return false
	var n := int(kind) / 1000
	give_money("1000", n)
	return true


# ------------------------------------------------------------------ 기계 설정
func default_settings(kind: String) -> Dictionary:
	if kind == "bridge":
		return {
			"name": "일본식 피규어 뽑기",
			"plays_per_1000": 1, "bonus_5000": 6, "accept_5000": true,
			"timer_sec": 30, "control_mode": "2button", "prong_count": 2,
			"power_grab": 70, "power_lift": 65, "power_top": 55, "power_carry": 55,
			"top_drop_delay": 0.3,
			"payout_mode": "skill", "payout_every": 20, "payout_revenue": 20000, "strong_power": 100,
			"move_speed": 0.18, "drop_speed": 0.16, "lift_speed": 0.14, "sway": 0.35,
			"drop_depth": 100, "open_angle": 45, "auto_drop": true, "start_from_home": true,
			"bridge_gap": 0.20, "bridge_layout": "2bar", "bar_friction": 0.35,
			"prize_ids": ["jp_figure_a", "jp_figure_b"],
		}
	if kind == "small":
		return {
			"name": "미니 인형뽑기",
			"plays_per_1000": 2, "bonus_5000": 12, "accept_5000": true,
			"timer_sec": 25, "control_mode": "joystick", "prong_count": 3,
			"power_grab": 80, "power_lift": 70, "power_top": 30, "power_carry": 25,
			"top_drop_delay": 0.25,
			"payout_mode": "count", "payout_every": 15, "payout_revenue": 6000, "strong_power": 100,
			"move_speed": 0.16, "drop_speed": 0.14, "lift_speed": 0.13, "sway": 0.5,
			"drop_depth": 100, "open_angle": 40, "auto_drop": true, "start_from_home": true,
			"prize_ids": ["chick", "duck", "mochi", "hamster", "whale", "mini_frog", "mini_bear", "mini_bunny", "snack", "capsule"],
		}
	return {
		"name": "왕인형 뽑기",
		"plays_per_1000": 1, "bonus_5000": 6, "accept_5000": true,
		"timer_sec": 30, "control_mode": "joystick", "prong_count": 3,
		"power_grab": 80, "power_lift": 70, "power_top": 30, "power_carry": 25,
		"top_drop_delay": 0.3,
		"payout_mode": "count", "payout_every": 15, "payout_revenue": 15000, "strong_power": 100,
		"move_speed": 0.2, "drop_speed": 0.17, "lift_speed": 0.15, "sway": 0.6, "warigari": true,
		"drop_depth": 100, "open_angle": 42, "auto_drop": true, "start_from_home": true,
		"prize_ids": ["bear", "bunny", "penguin", "dino", "cat", "panda", "shiba", "shark", "frog", "figure_box"],
	}


const PRESET_REV := 2


func get_settings(machine_id: String, kind: String, preset: Dictionary = {}) -> Dictionary:
	if not machine_settings.has(machine_id):
		var d := default_settings(kind)
		for k in preset:
			d[k] = preset[k]
		machine_settings[machine_id] = d
	else:
		# 새 항목이 생기면 기본값으로 채움
		var d := default_settings(kind)
		for k in d:
			if not machine_settings[machine_id].has(k):
				machine_settings[machine_id][k] = d[k]
		# 일본식 기계는 UFO 집게로 바뀌면서 팔 힘·벌림·봉 간격 기본값이 달라졌다 → 한 번 새 값으로
		var st: Dictionary = machine_settings[machine_id]
		if kind == "bridge" and int(st.get("_rev", 0)) < 6:
			for k in ["power_grab", "power_lift", "power_top", "power_carry", "open_angle", "bridge_gap", "prong_count", "bar_friction", "move_speed", "drop_speed", "lift_speed"]:
				st[k] = d[k]
			for k in preset:
				if k in ["bridge_gap"]:
					st[k] = preset[k]
			st["_rev"] = 6
			machine_prizes.erase(machine_id)
	if kind == "bridge":
		machine_settings[machine_id]["_rev"] = 6
	# 가게 구성(상품 목록·이름)이 새 버전으로 바뀌면 한 번 반영한다
	var ms: Dictionary = machine_settings[machine_id]
	if int(ms.get("_pz", 0)) < PRESET_REV:
		for k in ["prize_ids", "name"]:
			if preset.has(k):
				ms[k] = preset[k]
		ms["_pz"] = PRESET_REV
	return machine_settings[machine_id]


func set_setting(machine_id: String, key: String, value) -> void:
	if machine_settings.has(machine_id):
		machine_settings[machine_id][key] = value
		settings_changed.emit(machine_id)


func get_ledger(machine_id: String) -> Dictionary:
	if not ledgers.has(machine_id):
		ledgers[machine_id] = {"revenue": 0, "plays": 0, "payouts": 0, "payout_cost": 0,
			"plays_since_payout": 0, "revenue_since_payout": 0, "stocked_cost": 0}
	return ledgers[machine_id]


# ------------------------------------------------------------------ 획득
func add_to_collection(prize_id: String, colorway: int, machine: String) -> void:
	collection.append({"id": prize_id, "colorway": colorway, "machine": machine,
		"spent": spent_since_last_win, "time": Time.get_datetime_string_from_system()})
	spent_since_last_win = 0
	stats["wins"] = int(stats["wins"]) + 1
	collection_changed.emit()
	save_game()


func record_spend(amount: int) -> void:
	stats["spent"] = int(stats["spent"]) + amount
	spent_since_last_win += amount


func set_owner_mode(on: bool) -> void:
	owner_mode = on
	owner_mode_changed.emit(on)


func say(text: String) -> void:
	toast.emit(text)


# ------------------------------------------------------------------ 저장
func save_game() -> void:
	var data := {
		"wallet": wallet, "collection": collection, "machine_settings": machine_settings,
		"ledgers": ledgers, "stats": stats, "spent_since_last_win": spent_since_last_win,
		"bgm_volume": bgm_volume, "sfx_volume": sfx_volume, "mouse_sensitivity": mouse_sensitivity,
		"machine_prizes": machine_prizes, "game_speed": game_speed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## 기계 안 상품 배치(저장용) – machine_id → [Prize.save_state()]
var machine_prizes := {}


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	wallet = data.get("wallet", wallet)
	collection = data.get("collection", [])
	machine_settings = data.get("machine_settings", {})
	ledgers = data.get("ledgers", {})
	stats = data.get("stats", stats)
	spent_since_last_win = int(data.get("spent_since_last_win", 0))
	bgm_volume = float(data.get("bgm_volume", bgm_volume))
	sfx_volume = float(data.get("sfx_volume", sfx_volume))
	mouse_sensitivity = float(data.get("mouse_sensitivity", mouse_sensitivity))
	machine_prizes = data.get("machine_prizes", {})
	set_game_speed(float(data.get("game_speed", 1.0)))


func reset_all() -> void:
	wallet = {"10000": 3, "5000": 1, "1000": 10, "500": 4}
	collection = []
	machine_settings = {}
	ledgers = {}
	stats = {"plays": 0, "spent": 0, "wins": 0, "gacha": 0}
	machine_prizes = {}
	spent_since_last_win = 0
	save_game()


static func won(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out + "원"
