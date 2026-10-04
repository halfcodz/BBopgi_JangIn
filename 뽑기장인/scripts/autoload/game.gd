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


func _ready() -> void:
	_register_inputs()
	load_game()


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
			"power_grab": 75, "power_lift": 65, "power_top": 50, "power_carry": 40,
			"top_drop_delay": 0.3,
			"payout_mode": "skill", "payout_every": 20, "payout_revenue": 20000, "strong_power": 100,
			"move_speed": 0.18, "drop_speed": 0.16, "lift_speed": 0.14, "sway": 0.35,
			"drop_depth": 100, "open_angle": 52, "auto_drop": true, "start_from_home": true,
			"bridge_gap": 0.17, "bridge_layout": "2bar",
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
		"move_speed": 0.2, "drop_speed": 0.17, "lift_speed": 0.15, "sway": 0.6,
		"drop_depth": 100, "open_angle": 42, "auto_drop": true, "start_from_home": true,
		"prize_ids": ["bear", "bunny", "penguin", "dino", "cat", "panda", "shiba", "shark", "frog", "figure_box"],
	}


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
		"machine_prizes": machine_prizes,
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
