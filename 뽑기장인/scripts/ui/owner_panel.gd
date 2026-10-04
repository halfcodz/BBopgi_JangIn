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
	tab_claw = _scroll_tab("집게 힘·확률")
	tab_machine = _scroll_tab("기계 설정")
	tab_stock = _scroll_tab("상품 진열")
	tab_ledger = _scroll_tab("매출 장부")
	tabs.tab_changed.connect(func(_i): _refresh_ledger())


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
		machine_pick.add_item("%s  (%s)" % [m.settings.get("name", m.machine_id), "큰 기계" if m.kind == "big" else "작은 기계"])
	var pick: ClawMachine = target if target is ClawMachine else (_machines[0] if not _machines.is_empty() else null)
	if pick:
		machine_pick.select(_machines.find(pick))
		_select(pick)


func _select(m: ClawMachine) -> void:
	machine = m
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
	_slider(tab_machine, "레일 이동 속도", "move_speed", 0.06, 0.4, 0.01, "%.2f m/s")
	_slider(tab_machine, "하강 속도", "drop_speed", 0.06, 0.35, 0.01, "%.2f m/s")
	_slider(tab_machine, "상승 속도", "lift_speed", 0.06, 0.35, 0.01, "%.2f m/s")
	_slider(tab_machine, "줄 흔들림", "sway", 0.0, 1.0, 0.05, "%.2f", "높을수록 멈출 때 집게가 많이 흔들려요")
	_slider(tab_machine, "하강 깊이 한계", "drop_depth", 30, 100, 1, "%d%%", "100% = 바닥까지 내려감")


# ------------------------------------------------------------------ 상품 진열
func _build_stock_tab() -> void:
	_clear(tab_stock)
	place_label = UIKit.label("", 18, UIKit.PINK_DARK)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	place_label.custom_minimum_size = Vector2(440, 0)
	tab_stock.add_child(place_label)
	stock_label = UIKit.label("", 18)
	tab_stock.add_child(stock_label)
	var tg := CheckButton.new()
	tg.text = "클릭해서 놓기 모드 (왼쪽 클릭: 놓기 / 오른쪽 클릭: 빼기)"
	tg.button_pressed = place_mode
	tg.toggled.connect(func(b):
		place_mode = b
		_update_place_label())
	tab_stock.add_child(tg)
	tab_stock.add_child(UIKit.label("상품 고르기 (원가)", 19))
	var grid := GridContainer.new()
	grid.columns = 2
	tab_stock.add_child(grid)
	var ids := PrizeCatalog.ids_for(machine.kind)
	for id in ids:
		var b := UIKit.button("%s\n%s" % [PrizeCatalog.display_name(id), Game.won(PrizeCatalog.cost(id))], func():
			place_id = id
			_update_place_label(), UIKit.SKY if machine.kind == "small" else UIKit.PINK)
		b.custom_minimum_size = Vector2(215, 56)
		grid.add_child(b)
	var row := HBoxContainer.new()
	tab_stock.add_child(row)
	row.add_child(UIKit.button("선택 상품 5개 넣기", func():
		if place_id == "":
			hud.show_toast("먼저 상품을 고르세요")
			return
		machine.fill_random(5, [place_id])
		_after_stock()))
	row.add_child(UIKit.button("랜덤 10개 채우기", func():
		machine.fill_random(10)
		_after_stock()))
	var row2 := HBoxContainer.new()
	tab_stock.add_child(row2)
	row2.add_child(UIKit.button("모두 비우기", func():
		machine.clear_prizes()
		await get_tree().process_frame
		_after_stock(), Color(0.6, 0.55, 0.62)))
	row2.add_child(UIKit.button("흔들어 정리하기", func():
		for p in machine.get_prizes():
			p.wake()
			for b in p.bodies:
				b.apply_central_impulse(Vector3(randf_range(-0.2, 0.2), 0.5, randf_range(-0.2, 0.2)) * b.mass)
		hud.show_toast("기계를 툭툭 쳐서 인형들을 정리했어요")))
	tab_stock.add_child(UIKit.label("기계에 넣을 상품 종류(랜덤 채우기용)", 18))
	for id in ids:
		var c := CheckBox.new()
		c.text = PrizeCatalog.display_name(id)
		var cur: Array = machine.settings.get("prize_ids", [])
		c.button_pressed = id in cur
		c.toggled.connect(func(b):
			var arr: Array = machine.settings.get("prize_ids", []).duplicate()
			if b and not id in arr:
				arr.append(id)
			elif not b:
				arr.erase(id)
			if arr.is_empty():
				arr = [id]
			_apply("prize_ids", arr))
		tab_stock.add_child(c)
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
	stock_label.text = "현재 %d개 진열 · 진열 원가 %s" % [n, Game.won(worth)]
	if place_id == "":
		place_label.text = "상품을 고른 뒤 '클릭해서 놓기'를 켜고 기계 안을 클릭하세요."
	else:
		place_label.text = "선택: %s %s" % [PrizeCatalog.display_name(place_id), "· 기계 안을 클릭하면 놓아요" if place_mode else "(클릭해서 놓기 꺼짐)"]


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
func _refresh_ledger() -> void:
	if tab_ledger == null or machine == null:
		return
	_clear(tab_ledger)
	var lg := machine.ledger
	var rev := int(lg["revenue"])
	var cost := int(lg["payout_cost"])
	var rate := (float(cost) / rev * 100.0) if rev > 0 else 0.0
	var txt := "[%s]\n매출 %s · %d판\n배출 %d개 (원가 %s)\n순이익 %s · 원가율 %.1f%%\n" % [
		machine.settings["name"], Game.won(rev), int(lg["plays"]), int(lg["payouts"]), Game.won(cost), Game.won(rev - cost), rate]
	match String(machine.settings["payout_mode"]):
		"count":
			txt += "강집게까지 %d판 남음" % max(0, int(machine.settings["payout_every"]) - int(lg["plays_since_payout"]))
		"revenue":
			txt += "강집게까지 매출 %s 남음" % Game.won(max(0, int(machine.settings["payout_revenue"]) - int(lg["revenue_since_payout"])))
		_:
			txt += "실력 모드(강집게 없음)"
	tab_ledger.add_child(UIKit.label(txt, 20))
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
