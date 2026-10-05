class_name OwnerPanel
extends PanelContainer
## 사장 모드: 기계별 집게 힘·확률·가격·조작 방식 세팅, 상품 진열, 매출 장부, 금고

var hud
var player: Player
var shop: Node
var machine: ClawMachine
var machine_pick: OptionButton
var tabs: TabContainer
var tab_claw: VBoxContainer
var tab_machine: VBoxContainer
var tab_stock: VBoxContainer
var tab_ledger: VBoxContainer
var tab_easy: VBoxContainer
var tab_adv: VBoxContainer
var place_id := ""
var place_mode := false
var place_label: Label
var stock_label: Label
var ledger_label: Label
var _machines: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -520
	offset_right = -10
	offset_top = 10
	offset_bottom = -10
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(UIKit.title("👑 사장 모드", 28))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(UIKit.button("닫기", func(): hud._toggle_owner()))
	machine_pick = OptionButton.new()
	machine_pick.item_selected.connect(func(i): _select(_machines[i]))
	v.add_child(machine_pick)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tab_easy = _scroll_tab("① 쉬운 설정")
	tab_stock = _scroll_tab("② 상품")
	tab_ledger = _scroll_tab("③ 매출")
	tab_adv = _scroll_tab("⚙ 고급")
	tab_adv.add_child(UIKit.label("익숙해지면 숫자로 세세하게 조절해 보세요.", 16, Color(0.45, 0.35, 0.45)))
	tab_adv.add_child(UIKit.title("집게 힘·확률", 22))
	tab_claw = VBoxContainer.new()
	tab_adv.add_child(tab_claw)
	tab_adv.add_child(HSeparator.new())
	tab_adv.add_child(UIKit.title("기계 설정", 22))
	tab_machine = VBoxContainer.new()
	tab_adv.add_child(tab_machine)
	tabs.tab_changed.connect(func(_i):
		_refresh_ledger()
		_build_easy_tab())


func _scroll_tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func open_for(target) -> void:
	_machines = shop.machines if shop else []
	machine_pick.clear()
	for m in _machines:
		machine_pick.add_item("%s  (%s)" % [m.settings.get("name", m.machine_id), {"big": "큰 기계", "small": "작은 기계", "bridge": "피규어 기계"}.get(m.kind, m.kind)])
	var pick: ClawMachine = target if target is ClawMachine else (_machines[0] if not _machines.is_empty() else null)
	if pick:
		machine_pick.select(_machines.find(pick))
		_select(pick)


func _select(m: ClawMachine) -> void:
	machine = m
	_build_easy_tab()
	_build_claw_tab()
	_build_machine_tab()
	_build_stock_tab()
	_refresh_ledger()


func _clear(v: Container) -> void:
	for c in v.get_children():
		c.queue_free()


func _apply(key: String, value) -> void:
	Game.set_setting(machine.machine_id, key, value)


func _slider(parent: Container, title: String, key: String, mn: float, mx: float, step: float, fmt: String, help := "") -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)
	var top := HBoxContainer.new()
	row.add_child(top)
	var l := UIKit.label(title, 19)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l)
	var val := UIKit.label(fmt % float(machine.settings[key]), 19, UIKit.PINK_DARK)
	top.add_child(val)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(machine.settings[key])
	s.custom_minimum_size = Vector2(440, 22)
	s.value_changed.connect(func(x):
		val.text = fmt % x
		_apply(key, int(x) if step >= 1.0 else x))
	row.add_child(s)
	if help != "":
		var hl := UIKit.label(help, 15, Color(0.45, 0.35, 0.45))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hl.custom_minimum_size = Vector2(440, 0)
		row.add_child(hl)


func _option(parent: Container, title: String, key: String, items: Array, values: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := UIKit.label(title, 19)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	var cur := values.find(machine.settings[key])
	o.select(max(cur, 0))
	o.item_selected.connect(func(i): _apply(key, values[i]))
	row.add_child(o)


func _check(parent: Container, title: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = title
	c.button_pressed = bool(machine.settings[key])
	c.toggled.connect(func(b): _apply(key, b))
	parent.add_child(c)


# ------------------------------------------------------------------ 쉬운 설정
const LEVELS := [
	["😊 쉬움", "연습용 · 집게가 아주 세요", 100, 100, 100, 100, "skill", 10],
	["🙂 보통", "동네 뽑기방 느낌", 80, 70, 30, 25, "count", 15],
	["😤 어려움", "정상에서 힘이 쭉 빠져요", 65, 50, 20, 15, "count", 25],
	["💸 짠물", "매출이 쌓여야 겨우 뽑혀요", 55, 40, 12, 8, "revenue", 30],
]


## 일본식 UFO 기계 난이도: 팔 힘은 실제처럼 약하게 두고, 봉(다리) 간격으로 조절한다
const BRIDGE_LEVELS := [
	["😊 쉬움", "조금 기울어도 빠져요", 0.215],
	["🙂 보통", "거의 똑바로 서야 빠져요(실제 매장)", 0.20],
	["😤 어려움", "수직에 가까워야 빠져요", 0.19],
	["💸 짠물", "정확히 수직이어야 겨우 빠져요", 0.185],
]


func _current_level() -> int:
	var st := machine.settings
	if machine is BridgeMachine:
		for i in BRIDGE_LEVELS.size():
			if absf(float(st.get("bridge_gap", 0.20)) - BRIDGE_LEVELS[i][2]) < 0.001:
				return i
		return -1
	for i in LEVELS.size():
		var L: Array = LEVELS[i]
		if int(st["power_grab"]) == L[2] and int(st["power_lift"]) == L[3] and int(st["power_top"]) == L[4] and int(st["power_carry"]) == L[5] and String(st["payout_mode"]) == L[6]:
			return i
	return -1


func _apply_level(i: int) -> void:
	var L: Array = LEVELS[i]
	_apply("power_grab", L[2])
	_apply("power_lift", L[3])
	_apply("power_top", L[4])
	_apply("power_carry", L[5])
	_apply("payout_mode", L[6])
	if L[6] == "revenue":
		_apply("payout_revenue", L[7] * 1000)
	else:
		_apply("payout_every", L[7])
	hud.show_toast("난이도를 '%s'(으)로 바꿨어요" % String(L[0]).substr(2))


func _apply_bridge_level(i: int) -> void:
	_apply("bridge_gap", BRIDGE_LEVELS[i][2])
	hud.show_toast("난이도를 '%s'(으)로 바꿨어요" % String(BRIDGE_LEVELS[i][0]).substr(2))


func _big_choice(parent: Container, title: String, items: Array, current: int, cb: Callable, cols := 2) -> void:
	parent.add_child(UIKit.title(title, 22))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	for i in items.size():
		var txt: String = items[i]
		var col := UIKit.PINK if i == current else Color(0.82, 0.72, 0.8)
		var b := UIKit.button(("✔ " if i == current else "") + txt, func():
			cb.call(i)
			_build_easy_tab(), col)
		b.custom_minimum_size = Vector2(440.0 / cols - 6.0, 58 if txt.contains("\n") else 46)
		g.add_child(b)


func _build_easy_tab() -> void:
	if machine == null or tab_easy == null:
		return
	_clear(tab_easy)
	tab_easy.add_child(UIKit.label("버튼만 누르면 바로 적용돼요. 기계가 쉬고 있을 때 바꾸는 게 좋아요.", 16, Color(0.45, 0.35, 0.45)))
	var lv := []
	if machine is BridgeMachine:
		for L in BRIDGE_LEVELS:
			lv.append("%s\n%s" % [L[0], L[1]])
		_big_choice(tab_easy, "뽑기 난이도", lv, _current_level(), _apply_bridge_level)
	else:
		for L in LEVELS:
			lv.append("%s\n%s" % [L[0], L[1]])
		_big_choice(tab_easy, "뽑기 난이도", lv, _current_level(), _apply_level)
	var per := int(machine.settings["plays_per_1000"])
	_big_choice(tab_easy, "가격", ["1,000원에 1판", "1,000원에 2판", "1,000원에 3판"], per - 1, func(i):
		_apply("plays_per_1000", i + 1)
		_apply("bonus_5000", (i + 1) * 6), 3)
	var times := [15, 30, 45, 60]
	_big_choice(tab_easy, "제한 시간", ["15초", "30초", "45초", "60초"], times.find(int(machine.settings["timer_sec"])), func(i): _apply("timer_sec", times[i]), 4)
	var modes := ["joystick", "2button"]
	_big_choice(tab_easy, "조작 방법", ["🕹 조이스틱 + 버튼", "🔘 버튼 2개(→ 후 ↑)"], modes.find(String(machine.settings["control_mode"])), func(i): _apply("control_mode", modes[i]))
	if not machine is BridgeMachine:
		_big_choice(tab_easy, "집게 발", ["3발 집게", "2발 집게"], 0 if int(machine.settings["prong_count"]) == 3 else 1, func(i): _apply("prong_count", 3 if i == 0 else 2))
	var sways := [0.0, 0.5, 0.9, 1.6]
	var sw := float(machine.settings["sway"])
	var cur_sway := 0 if sw < 0.25 else (1 if sw < 0.7 else (2 if sw < 1.25 else 3))
	_big_choice(tab_easy, "줄 흔들림", ["없음", "보통", "많이", "아주 출렁"], cur_sway, func(i): _apply("sway", sways[i]), 4)
	# 집게 속도(레일·하강·상승 한 번에)
	var speeds := [[0.12, 0.1, 0.1], [0.2, 0.17, 0.15], [0.4, 0.32, 0.3], [0.75, 0.6, 0.55]]
	var mv := float(machine.settings["move_speed"])
	var cur_sp := 0 if mv < 0.16 else (1 if mv < 0.3 else (2 if mv < 0.55 else 3))
	_big_choice(tab_easy, "집게 속도 (레일·하강·상승)", ["느리게", "보통", "빠르게", "아주 빠르게"], cur_sp, func(i):
		_apply("move_speed", speeds[i][0])
		_apply("drop_speed", speeds[i][1])
		_apply("lift_speed", speeds[i][2]), 4)
	if machine is BridgeMachine:
		var lays := ["2bar", "3bar", "v", "step"]
		_big_choice(tab_easy, "다리 모양 (실제 일본 기계 세팅)", ["기본 2봉 다리", "3봉 다리", "ハの字 (벌어지는 다리)", "단차 다리 (뒤가 높음)"], lays.find(String(machine.settings.get("bridge_layout", "2bar"))), func(i): _apply("bridge_layout", lays[i]))


# ------------------------------------------------------------------ 집게 힘·확률
func _build_claw_tab() -> void:
	_clear(tab_claw)
	tab_claw.add_child(UIKit.label("실제 가게처럼 단계별 집게 힘(솔레노이드 전압)을 정합니다.", 16))
	_slider(tab_claw, "잡을 때 힘", "power_grab", 0, 100, 1, "%d%%", "바닥에서 발을 오므리는 힘")
	_slider(tab_claw, "올라갈 때 힘", "power_lift", 0, 100, 1, "%d%%", "들어 올리는 동안의 힘")
	_slider(tab_claw, "정상 도착 힘", "power_top", 0, 100, 1, "%d%%", "꼭대기에서 힘이 빠지는 '정상 드롭'")
	_slider(tab_claw, "정상 드롭 시점", "top_drop_delay", 0.0, 2.0, 0.05, "%.2f초")
	_slider(tab_claw, "배출구로 이동 중 힘", "power_carry", 0, 100, 1, "%d%%")
	tab_claw.add_child(HSeparator.new())
	_option(tab_claw, "확률(강집게) 방식", "payout_mode", ["실력(항상 설정 힘)", "N판마다 강집게", "매출 기준 강집게"], ["skill", "count", "revenue"])
	_slider(tab_claw, "강집게 주기", "payout_every", 1, 60, 1, "%d판마다")
	_slider(tab_claw, "강집게 매출 기준", "payout_revenue", 1000, 60000, 500, "%d원")
	_slider(tab_claw, "강집게 힘", "strong_power", 30, 100, 1, "%d%%")
	var presets := HBoxContainer.new()
	tab_claw.add_child(UIKit.label("빠른 프리셋", 18))
	tab_claw.add_child(presets)
	presets.add_child(UIKit.button("연습용(쎈 집게)", func(): _preset(100, 100, 100, 100, "skill")))
	presets.add_child(UIKit.button("보통 가게", func(): _preset(80, 70, 30, 25, "count")))
	presets.add_child(UIKit.button("짠물 가게", func(): _preset(55, 40, 15, 10, "revenue"), Color(0.55, 0.45, 0.6)))


func _preset(g: int, l: int, t: int, c: int, mode: String) -> void:
	_apply("power_grab", g)
	_apply("power_lift", l)
	_apply("power_top", t)
	_apply("power_carry", c)
	_apply("payout_mode", mode)
	_build_claw_tab()
	hud.show_toast("집게 세팅을 바꿨어요")


# ------------------------------------------------------------------ 기계 설정
func _build_machine_tab() -> void:
	_clear(tab_machine)
	var row := HBoxContainer.new()
	tab_machine.add_child(row)
	row.add_child(UIKit.label("기계 이름", 19))
	var le := LineEdit.new()
	le.text = String(machine.settings["name"])
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_changed.connect(func(t): _apply("name", t))
	row.add_child(le)
	_slider(tab_machine, "1,000원당 판수", "plays_per_1000", 1, 5, 1, "%d판")
	_check(tab_machine, "5,000원권 받기", "accept_5000")
	_slider(tab_machine, "5,000원 넣으면", "bonus_5000", 1, 20, 1, "%d판")
	_slider(tab_machine, "제한 시간", "timer_sec", 5, 60, 1, "%d초")
	_check(tab_machine, "시간이 끝나면 자동으로 내려가기", "auto_drop")
	_option(tab_machine, "조작 방식", "control_mode", ["조이스틱 + 버튼", "2버튼(→ 후 ↑)"], ["joystick", "2button"])
	_option(tab_machine, "집게 발 개수", "prong_count", ["3발", "2발"], [3, 2])
	_slider(tab_machine, "발 벌림 각도", "open_angle", 20, 60, 1, "%d°", "넓게 벌리면 큰 인형에 유리, 좁으면 작은 상품에 유리 (기계가 쉬고 있을 때 적용)")
	_slider(tab_machine, "레일 이동 속도", "move_speed", 0.04, 1.2, 0.01, "%.2f m/s")
	_slider(tab_machine, "하강 속도", "drop_speed", 0.04, 1.0, 0.01, "%.2f m/s")
	_slider(tab_machine, "상승 속도", "lift_speed", 0.04, 1.0, 0.01, "%.2f m/s")
	_slider(tab_machine, "줄 흔들림", "sway", 0.0, 2.0, 0.05, "%.2f", "높을수록 멈출 때 집게가 많이 흔들려요(1 이상은 아주 출렁)")
	_slider(tab_machine, "하강 깊이 한계", "drop_depth", 30, 100, 1, "%d%%", "100% = 바닥까지 내려감")
	if machine.kind == "big" and not machine is BridgeMachine:
		_check(tab_machine, "와리가리 허용 (줄을 흔들어 뽑기)", "warigari")


# ------------------------------------------------------------------ 상품 진열
func _build_stock_tab() -> void:
	_clear(tab_stock)
	stock_label = UIKit.title("", 22)
	tab_stock.add_child(stock_label)
	var bridge := machine is BridgeMachine
	var row := HBoxContainer.new()
	tab_stock.add_child(row)
	if bridge:
		row.add_child(UIKit.button("🎁 피규어 다시 올리기", func():
			machine.clear_prizes()
			await get_tree().process_frame
			machine.fill_random(1)
			_after_stock()))
	else:
		row.add_child(UIKit.button("🎲 랜덤으로 10개 채우기", func():
			machine.fill_random(10)
			_after_stock()))
		row.add_child(UIKit.button("툭툭 정리", func():
			for p in machine.get_prizes():
				p.wake()
				for bd in p.bodies:
					bd.apply_central_impulse(Vector3(randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2)) * bd.mass)
			hud.show_toast("기계를 툭툭 쳐서 인형들을 정리했어요")))
	tab_stock.add_child(UIKit.button("모두 비우기", func():
		machine.clear_prizes()
		await get_tree().process_frame
		_after_stock(), Color(0.6, 0.55, 0.62)))
	tab_stock.add_child(HSeparator.new())
	tab_stock.add_child(UIKit.title("하나씩 넣기", 22))
	tab_stock.add_child(UIKit.label("누를 때마다 기계 안 빈자리에 1개씩 들어가요 (괄호 = 사장님 원가)", 16, Color(0.45, 0.35, 0.45)))
	var grid := GridContainer.new()
	grid.columns = 2
	tab_stock.add_child(grid)
	var ids := PrizeCatalog.ids_for(machine.kind)
	for id in ids:
		var b := UIKit.button("+ %s\n(%s)" % [PrizeCatalog.display_name(id), Game.won(PrizeCatalog.cost(id))], func():
			place_id = id
			if bridge:
				machine.fill_random(1, [id])
			else:
				machine.fill_random(1, [id])
			_after_stock(), UIKit.SKY if machine.kind == "small" else UIKit.PINK)
		b.custom_minimum_size = Vector2(215, 58)
		grid.add_child(b)
	tab_stock.add_child(HSeparator.new())
	var tg := CheckButton.new()
	tg.text = "직접 놓기: 위에서 고른 상품을 기계 안 클릭한 곳에 놓기\n(오른쪽 클릭 = 빼기)"
	tg.button_pressed = place_mode
	tg.toggled.connect(func(on):
		place_mode = on
		_update_place_label())
	tab_stock.add_child(tg)
	place_label = UIKit.label("", 16, UIKit.PINK_DARK)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	place_label.custom_minimum_size = Vector2(440, 0)
	tab_stock.add_child(place_label)
	_update_place_label()


func _after_stock() -> void:
	machine.save_layout()
	_update_place_label()


func _update_place_label() -> void:
	if place_label == null or machine == null:
		return
	var n := machine.get_prizes().size()
	var worth := 0
	for p in machine.get_prizes():
		worth += p.cost
	stock_label.text = "지금 %d개 들어 있어요 (원가 %s)" % [n, Game.won(worth)]
	if not place_mode:
		place_label.text = ""
	elif place_id == "":
		place_label.text = "먼저 위에서 상품을 하나 누르세요."
	else:
		place_label.text = "선택: %s · 기계 안을 클릭하면 놓아요" % PrizeCatalog.display_name(place_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not place_mode or machine == null or player == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var cam := player.camera
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 6.0, 1 | 2)
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return
		if event.button_index == MOUSE_BUTTON_LEFT and place_id != "":
			var lp := machine.to_local(hit["position"])
			if abs(lp.x) > machine.ix or lp.z < machine.z_back or lp.z > machine.z_front or lp.y < machine.base_h - 0.05 or lp.y > machine.glass_top:
				hud.show_toast("기계 안쪽을 클릭하세요")
				return
			lp.y = max(lp.y, machine.base_h) + 0.18
			machine.add_prize(place_id, machine.to_global(lp), randf() * TAU)
			Sfx.play("plush_thud", -6.0)
			_after_stock()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var col = hit["collider"]
			var p = col.get_parent() if col else null
			if p is Prize:
				machine.remove_prize(p)
				await get_tree().process_frame
				_after_stock()
				get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ 매출 장부
func _tile(title: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.9, 0.94)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(215, 74)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UIKit.label(title, 16))
	v.add_child(UIKit.title(value, 24))
	return p


func _refresh_ledger() -> void:
	if tab_ledger == null or machine == null:
		return
	_clear(tab_ledger)
	var lg := machine.ledger
	var rev := int(lg["revenue"])
	var cost := int(lg["payout_cost"])
	var rate := (float(cost) / rev * 100.0) if rev > 0 else 0.0
	tab_ledger.add_child(UIKit.title(String(machine.settings["name"]), 22))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	tab_ledger.add_child(g)
	g.add_child(_tile("💰 매출", Game.won(rev)))
	g.add_child(_tile("🎮 플레이", "%d판" % int(lg["plays"])))
	g.add_child(_tile("🧸 나간 상품", "%d개" % int(lg["payouts"])))
	g.add_child(_tile("📈 순이익", Game.won(rev - cost)))
	var txt := ""
	match String(machine.settings["payout_mode"]):
		"count":
			txt = "다음 강집게까지 %d판 남았어요" % max(0, int(machine.settings["payout_every"]) - int(lg["plays_since_payout"]))
		"revenue":
			txt = "다음 강집게까지 매출 %s 남았어요" % Game.won(max(0, int(machine.settings["payout_revenue"]) - int(lg["revenue_since_payout"])))
		_:
			txt = "실력 모드라 강집게가 없어요"
	tab_ledger.add_child(UIKit.label(txt + "  (원가율 %.0f%%)" % rate, 18))
	tab_ledger.add_child(HSeparator.new())
	var total_rev := 0
	var total_cost := 0
	for m in _machines:
		total_rev += int(m.ledger["revenue"])
		total_cost += int(m.ledger["payout_cost"])
	var safe := total_rev - int(Game.stats.get("withdrawn", 0))
	tab_ledger.add_child(UIKit.label("가게 전체 매출 %s\n배출 원가 %s · 순이익 %s\n금고 잔액 %s" % [
		Game.won(total_rev), Game.won(total_cost), Game.won(total_rev - total_cost), Game.won(safe)], 20))
	tab_ledger.add_child(UIKit.button("금고에서 10,000원 꺼내기", func():
		var safe2 := 0
		for m in _machines:
			safe2 += int(m.ledger["revenue"])
		safe2 -= int(Game.stats.get("withdrawn", 0))
		if safe2 < 10000:
			hud.show_toast("금고에 10,000원이 없어요")
			return
		Game.stats["withdrawn"] = int(Game.stats.get("withdrawn", 0)) + 10000
		Game.give_money("10000", 1)
		Sfx.play("coin")
		_refresh_ledger()))
	tab_ledger.add_child(UIKit.button("연습용 용돈 받기 (+50,000원)", func():
		Game.give_money("10000", 5)
		Sfx.play("coin")
		hud.show_toast("지갑에 50,000원이 들어왔어요")))
	tab_ledger.add_child(UIKit.button("이 기계 장부 초기화", func():
		for k in lg:
			lg[k] = 0
		_refresh_ledger(), Color(0.6, 0.55, 0.62)))
