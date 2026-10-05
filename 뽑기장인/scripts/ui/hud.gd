class_name HUD
extends CanvasLayer
## 화면 표시: 지갑, 상호작용 안내, 기계 조작 패널, 알림, 도움말, 내 수집함, 일시정지 메뉴

var player: Player
var shop: Node
var wallet_box: HBoxContainer
var wallet_total: Label
var prompt: Label
var crosshair: Control
var machine_panel: PanelContainer
var mp_name: Label
var mp_info: Label
var mp_state: Label
var mp_big: Label
var inspector: Inspector
var mp_keys: Label
var mp_key: Label
var bridge_guide: BridgeGuide
var toast_box: VBoxContainer
var help_panel: PanelContainer
var pause_panel: PanelContainer
var collection_panel: PanelContainer
var collection_grid: GridContainer
var collection_stats: Label
var owner_badge: Label
var stats_label: Label
var owner_panel: OwnerPanel
var _bill_labels := {}


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	# 지갑
	var wp := PanelContainer.new()
	wp.position = Vector2(16, 16)
	root.add_child(wp)
	var wv := VBoxContainer.new()
	wp.add_child(wv)
	wv.add_child(UIKit.title("내 지갑", 22))
	wallet_box = HBoxContainer.new()
	wallet_box.add_theme_constant_override("separation", 10)
	wv.add_child(wallet_box)
	for k in ["10000", "5000", "1000", "500"]:
		var col := VBoxContainer.new()
		var icon := TextureRect.new()
		if k != "500":
			icon.texture = load("res://assets/textures/ui/bill_%s.png" % k)
		icon.custom_minimum_size = Vector2(64, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if k == "500":
			var coin := Label.new()
			coin.text = "🪙500"
			coin.custom_minimum_size = Vector2(64, 30)
			coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(coin)
		else:
			col.add_child(icon)
		var l := UIKit.label("x0", 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		_bill_labels[k] = l
		wallet_box.add_child(col)
	wallet_total = UIKit.label("", 18)
	wv.add_child(wallet_total)

	# 오른쪽 위: 사장 모드 배지 + 획득 수
	var rv := VBoxContainer.new()
	rv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rv.position = Vector2(-330, 16)
	rv.custom_minimum_size = Vector2(310, 0)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rv)
	owner_badge = UIKit.title("👑 사장 모드", 26)
	owner_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	owner_badge.visible = false
	rv.add_child(owner_badge)
	stats_label = UIKit.label("", 18, Color.WHITE)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_color_override("font_outline_color", UIKit.INK)
	stats_label.add_theme_constant_override("outline_size", 6)
	rv.add_child(stats_label)

	# 조준점
	crosshair = ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.85)
	crosshair.size = Vector2(6, 6)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-3, -3)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# 상호작용 안내
	prompt = UIKit.label("", 26, Color.WHITE)
	prompt.add_theme_color_override("font_outline_color", UIKit.INK)
	prompt.add_theme_constant_override("outline_size", 10)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-400, -150)
	prompt.size = Vector2(800, 40)
	root.add_child(prompt)

	# 기계 조작 패널(오른쪽 아래): 지금 할 일 하나만 크게 보여 준다
	machine_panel = PanelContainer.new()
	machine_panel.anchor_left = 1.0
	machine_panel.anchor_right = 1.0
	machine_panel.anchor_top = 1.0
	machine_panel.anchor_bottom = 1.0
	machine_panel.offset_left = -440
	machine_panel.offset_right = -20
	machine_panel.offset_top = -60
	machine_panel.offset_bottom = -20
	machine_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	machine_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	machine_panel.visible = false
	machine_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(machine_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 6)
	machine_panel.add_child(mv)
	var mh := HBoxContainer.new()
	mv.add_child(mh)
	mp_name = UIKit.title("", 22)
	mp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(mp_name)
	mp_info = UIKit.label("", 16, Color(0.5, 0.4, 0.5))
	mh.add_child(mp_info)
	mp_big = UIKit.title("", 30)
	mv.add_child(mp_big)
	# 지금 할 일: 키 모양 + 설명
	var step := HBoxContainer.new()
	step.add_theme_constant_override("separation", 10)
	mv.add_child(step)
	mp_key = Label.new()
	mp_key.add_theme_font_size_override("font_size", 26)
	mp_key.add_theme_color_override("font_color", Color.WHITE)
	var kb := StyleBoxFlat.new()
	kb.bg_color = UIKit.PINK_DARK
	kb.set_corner_radius_all(10)
	kb.content_margin_left = 12
	kb.content_margin_right = 12
	kb.content_margin_top = 2
	kb.content_margin_bottom = 4
	mp_key.add_theme_stylebox_override("normal", kb)
	mp_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step.add_child(mp_key)
	mp_state = UIKit.label("", 22)
	mp_state.autowrap_mode = TextServer.AUTOWRAP_WORD
	mp_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_state.custom_minimum_size = Vector2(300, 0)
	step.add_child(mp_state)
	mp_keys = UIKit.label("", 15, Color(0.5, 0.4, 0.5))
	mv.add_child(mp_keys)

	# 일본식 기계 공략 도우미(오른쪽, 조작 패널 위)
	bridge_guide = BridgeGuide.new()
	bridge_guide.anchor_left = 1.0
	bridge_guide.anchor_right = 1.0
	bridge_guide.anchor_top = 1.0
	bridge_guide.anchor_bottom = 1.0
	bridge_guide.offset_left = -300
	bridge_guide.offset_right = -20
	bridge_guide.offset_top = -560
	bridge_guide.offset_bottom = -200
	bridge_guide.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bridge_guide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bridge_guide.visible = false
	root.add_child(bridge_guide)

	# 알림
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-360, 90)
	toast_box.custom_minimum_size = Vector2(720, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)

	_build_help(root)
	_build_pause(root)
	_build_collection(root)

	inspector = Inspector.new()
	inspector.hud = self
	root.add_child(inspector)

	owner_panel = OwnerPanel.new()
	owner_panel.hud = self
	root.add_child(owner_panel)
	owner_panel.visible = false

	var hint := UIKit.label("[H] 도움말   [I] 내 수집함   [F1/Tab] 사장 모드   [Esc] 메뉴", 16, Color.WHITE)
	hint.add_theme_color_override("font_outline_color", UIKit.INK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(16, -34)
	root.add_child(hint)

	Game.wallet_changed.connect(_refresh_wallet)
	Game.collection_changed.connect(_refresh_stats)
	Game.toast.connect(show_toast)
	Game.owner_mode_changed.connect(func(on): owner_badge.visible = on)
	_refresh_wallet()
	_refresh_stats()


func bind(p: Player, s: Node) -> void:
	player = p
	shop = s
	owner_panel.player = p
	owner_panel.shop = s
	p.focus_changed.connect(_on_focus)
	p.mode_changed.connect(_on_mode)


# ------------------------------------------------------------------ 갱신
func _refresh_wallet() -> void:
	for k in _bill_labels:
		_bill_labels[k].text = "x%d" % int(Game.wallet.get(k, 0))
	wallet_total.text = "합계 %s" % Game.won(Game.cash_total())


func _refresh_stats() -> void:
	var st := Game.stats
	stats_label.text = "도전 %d판 · 획득 %d개\n쓴 돈 %s" % [int(st["plays"]), Game.collection.size(), Game.won(int(st["spent"]))]


func _on_focus(target) -> void:
	if target == null:
		prompt.text = ""
	elif target is ClawMachine:
		var m: ClawMachine = target
		var extra := ""
		if not m.prizes_in_bin().is_empty():
			extra = "  (배출구에 상품 있음!)"
		prompt.text = "[E] %s 하기 · %s%s" % [m.settings.get("name", "인형뽑기"), m.price_text().replace("\n", " / "), extra]
	elif target.has_method("interact_prompt"):
		prompt.text = target.interact_prompt()


func _on_mode(mode: int) -> void:
	machine_panel.visible = mode == Player.Mode.MACHINE
	crosshair.visible = mode == Player.Mode.WALK
	prompt.visible = mode == Player.Mode.WALK


func _process(_delta: float) -> void:
	var on_bridge: bool = player != null and player.mode == Player.Mode.MACHINE and player.machine is BridgeMachine
	bridge_guide.visible = on_bridge
	if on_bridge:
		bridge_guide.machine = player.machine
	if player and player.mode == Player.Mode.MACHINE and player.machine:
		var m: ClawMachine = player.machine
		mp_name.text = String(m.settings.get("name", "인형뽑기"))
		mp_info.text = m.price_text().replace("\n", " · ")
		var moving := m.state == ClawMachine.State.MOVING
		var t_txt := "%d" % int(ceil(m.time_left)) if moving else "--"
		mp_big.text = "CREDIT %d   TIME %s" % [m.credits, t_txt]
		mp_big.add_theme_color_override("font_color", Color(0.9, 0.15, 0.25) if (moving and m.time_left <= 5.0) else UIKit.PINK_DARK)
		var g := _guide(m)
		mp_key.text = g[0]
		mp_key.visible = g[0] != ""
		mp_state.text = g[1]
		var extra := ""
		if Game.owner_mode:
			extra = "   · 강집게 %s" % ("다음 판 ON" if _next_strong(m) else "OFF")
		mp_keys.text = "C 시점(%s) · +/- 확대 · Q 나가기%s" % [Player.VIEW_NAMES[player.view_index], extra]
	elif player and player.mode == Player.Mode.WALK and player.focus and player.focus.has_method("interact_prompt"):
		prompt.text = player.focus.interact_prompt()
	if inspector and inspector.visible:
		if Engine.get_process_frames() > inspector.opened_frame + 1 and (Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("interact")):
			inspector.close()
		return
	if Input.is_action_just_pressed("help"):
		help_panel.visible = not help_panel.visible
	if Input.is_action_just_pressed("collection") and not owner_panel.visible:
		_toggle_collection()
	if Input.is_action_just_pressed("owner_mode"):
		_toggle_owner()
	if Input.is_action_just_pressed("menu") and player:
		if help_panel.visible:
			help_panel.visible = false
		elif collection_panel.visible:
			_toggle_collection()
		elif owner_panel.visible:
			_toggle_owner()
		else:
			_toggle_pause()


## 지금 해야 할 일 한 가지: [키, 설명]
func _guide(m: ClawMachine) -> Array:
	var bin_n := m.prizes_in_bin().size()
	if bin_n > 0 and m.state != ClawMachine.State.MOVING:
		return ["E", "🎁 상품 GET! 배출구에서 꺼내기"]
	var two := String(m.settings["control_mode"]) == "2button"
	match m.state:
		ClawMachine.State.IDLE:
			if m.credits > 0:
				return ["", "곧 시작해요..."]
			if Game.cash_total() <= 0:
				return ["", "돈이 없어요! 지폐교환기·카운터를 확인하세요"]
			return ["B", "1,000원 넣기  (N = 5,000원)"]
		ClawMachine.State.MOVING:
			if m.drop_requested:
				return ["", "집게가 내려가요!"]
			if two:
				if not m.btn1_used:
					return ["D", "누르는 동안 → 오른쪽으로 (떼면 끝)"]
				return ["W", "누르는 동안 ↑ 안쪽으로 · 떼면 내려가요"]
			return ["WASD", "집게 움직이기 → Space 로 내리기"]
		ClawMachine.State.OPENING, ClawMachine.State.DESCENDING:
			return ["", "⬇ 내려가는 중..."]
		ClawMachine.State.GRABBING:
			return ["", "✊ 집는 중!"]
		ClawMachine.State.LIFTING, ClawMachine.State.TOP_HOLD:
			return ["", "⬆ 올라가는 중... 두근두근"]
		_:
			return ["", "배출구로 돌아가는 중..."]


func _next_strong(m: ClawMachine) -> bool:
	match String(m.settings["payout_mode"]):
		"count":
			return int(m.ledger["plays_since_payout"]) + 1 >= int(m.settings["payout_every"])
		"revenue":
			return int(m.ledger["revenue_since_payout"]) + 1000 / int(m.settings["plays_per_1000"]) >= int(m.settings["payout_revenue"])
	return false


func show_toast(text: String) -> void:
	# 같은 알림이 이미 떠 있으면 새로 쌓지 않고 그 알림만 다시 보여 준다
	for c in toast_box.get_children():
		if c.has_meta("text") and String(c.get_meta("text")) == text and not c.is_queued_for_deletion():
			c.modulate.a = 1.0
			var old_tw = c.get_meta("tween")
			if old_tw and old_tw.is_valid():
				old_tw.kill()
			c.set_meta("tween", _fade_toast(c))
			return
	var p := PanelContainer.new()
	p.set_meta("text", text)
	var l := UIKit.label(text, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	p.add_child(l)
	toast_box.add_child(p)
	if toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
	p.set_meta("tween", _fade_toast(p))


func _fade_toast(p: Control) -> Tween:
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	return tw


# ------------------------------------------------------------------ 도움말
func _build_help(root: Control) -> void:
	help_panel = PanelContainer.new()
	help_panel.set_anchors_preset(Control.PRESET_CENTER)
	help_panel.position = Vector2(-400, -300)
	help_panel.custom_minimum_size = Vector2(800, 600)
	help_panel.visible = false
	root.add_child(help_panel)
	var v := VBoxContainer.new()
	help_panel.add_child(v)
	v.add_child(UIKit.title("뽑기장인 사용 설명서"))
	var txt := """[걷기] WASD 이동 · Shift 달리기 · Space 점프 · Ctrl 앉기(앉아서 걷기) · 마우스 둘러보기 · E 상호작용 · +/- 또는 휠로 확대/축소
[인형뽑기] 기계 앞에서 E → B로 1,000원(N은 5,000원) 넣기 → 시간 안에 조이스틱 이동 → Space로 집게 내리기
  · C: 정면 → 오른쪽 비스듬히 → 왼쪽 비스듬히 → 가까이 (깊이 확인!)  · +/- : 확대·축소
  · 집게는 줄에 매달려 흔들립니다. 멈춘 뒤 흔들림이 잦아들 때 내리세요.
  · [와리가리] 큰 기계만! 집게가 흔들리는 박자에 맞춰 좌우(또는 앞뒤)로 톡톡 밀면 점점 크게 흔들려요.
    가장 멀리 갔을 때 Space → 레일은 탁 멈추고 집게는 흔들리며 내려가 인형 사이로 깊게 파고들어요.
  · 인형이 배출구로 떨어지면 E로 꺼내세요.  · Q: 기계에서 나와 걷기
[큰 기계] 1회 1,000원 · 인형/전자기기 경품   [작은 기계] 1,000원 2회 · 키캡 키링·말랑이·팝잇·슬라임 등
[일본식 UFO 피규어 기계] 무거운 상자는 통째로 안 들려요. 끝을 살짝 들어 조금씩 밀고, 봉 사이로 기운 상자는 들린 쪽을 들어 세우세요. 거의 똑바로 서야 빠져요.
[2버튼 기계] D(→)를 누르는 동안 오른쪽 ①, W(↑)를 누르는 동안 안쪽 ② → 떼면 바로 내려갑니다.
[나의 전시실] 가게 안쪽 금색 문 너머 방 — 진열된 인형을 보고 E → 확대 보기(드래그로 돌리기, 휠/+/-로 확대)
[음료 자판기] 마시고 싶은 음료를 바라보고 E → 1,000원 → 꺼내는 곳에서 E로 꺼내 마시기
[지폐교환기] 큰 지폐를 1,000원권으로   [캡슐뽑기] 돈을 넣고 손잡이를 돌려요
[사장 모드] F1/Tab 또는 카운터에서 E — 난이도·가격·시간을 버튼 하나로, 상품 채우기, 매출 보기
[I] 내 수집함   [H] 이 도움말   [Esc] 메뉴"""
	var l := UIKit.label(txt, 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(l)
	v.add_child(UIKit.button("닫기 (H)", func(): help_panel.visible = false))


# ------------------------------------------------------------------ 일시정지
func _build_pause(root: Control) -> void:
	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-240, -260)
	pause_panel.custom_minimum_size = Vector2(480, 520)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pause_panel.add_child(v)
	v.add_child(UIKit.title("메뉴"))
	v.add_child(UIKit.button("계속하기", _toggle_pause))
	v.add_child(UIKit.label("배경음악", 18))
	var bgm := HSlider.new()
	bgm.min_value = 0
	bgm.max_value = 1
	bgm.step = 0.05
	bgm.value = Game.bgm_volume
	bgm.value_changed.connect(func(v2): Sfx.set_bgm_volume(v2))
	v.add_child(bgm)
	v.add_child(UIKit.label("효과음", 18))
	var sfx := HSlider.new()
	sfx.min_value = 0
	sfx.max_value = 1
	sfx.step = 0.05
	sfx.value = Game.sfx_volume
	sfx.value_changed.connect(func(v2): Game.sfx_volume = v2)
	v.add_child(sfx)
	v.add_child(UIKit.label("마우스 감도", 18))
	var ms := HSlider.new()
	ms.min_value = 0.0006
	ms.max_value = 0.006
	ms.step = 0.0002
	ms.value = Game.mouse_sensitivity
	ms.value_changed.connect(func(v2): Game.mouse_sensitivity = v2)
	v.add_child(ms)
	v.add_child(UIKit.button("저장하기", func():
		if shop:
			shop.save_all()
		Game.save_game()
		show_toast("저장했어요")))
	v.add_child(UIKit.button("처음부터 다시(초기화)", func():
		Game.reset_all()
		get_tree().reload_current_scene(), Color(0.6, 0.6, 0.65)))
	v.add_child(UIKit.button("게임 종료", func():
		if shop:
			shop.save_all()
		Game.save_game()
		get_tree().quit(), Color(0.5, 0.5, 0.55)))


func _toggle_pause() -> void:
	pause_panel.visible = not pause_panel.visible
	if player:
		player.set_ui_open(pause_panel.visible)


# ------------------------------------------------------------------ 내 수집함
func _build_collection(root: Control) -> void:
	collection_panel = PanelContainer.new()
	collection_panel.set_anchors_preset(Control.PRESET_CENTER)
	collection_panel.position = Vector2(-460, -320)
	collection_panel.custom_minimum_size = Vector2(920, 640)
	collection_panel.visible = false
	root.add_child(collection_panel)
	var v := VBoxContainer.new()
	collection_panel.add_child(v)
	v.add_child(UIKit.title("내 수집함 🧸"))
	v.add_child(UIKit.label("이름을 누르면 돌려 보며 자세히 볼 수 있어요", 16, Color(0.45, 0.35, 0.45)))
	collection_stats = UIKit.label("", 20)
	v.add_child(collection_stats)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(880, 470)
	v.add_child(sc)
	collection_grid = GridContainer.new()
	collection_grid.columns = 3
	collection_grid.add_theme_constant_override("h_separation", 24)
	sc.add_child(collection_grid)
	v.add_child(UIKit.button("닫기 (I)", _toggle_collection))


func _toggle_collection() -> void:
	collection_panel.visible = not collection_panel.visible
	if player:
		player.set_ui_open(collection_panel.visible)
	if collection_panel.visible:
		for c in collection_grid.get_children():
			c.queue_free()
		var counts := {}
		for e in Game.collection:
			counts[e["id"]] = int(counts.get(e["id"], 0)) + 1
		for id in counts:
			var last := -1
			for k in Game.collection.size():
				if Game.collection[k]["id"] == id:
					last = k
			var idx := last
			var b := UIKit.button("%s  x%d  🔍" % [PrizeCatalog.display_name(id), counts[id]], func(): open_inspector(idx))
			b.custom_minimum_size = Vector2(280, 44)
			collection_grid.add_child(b)
		var n := Game.collection.size()
		var spent := int(Game.stats["spent"])
		var avg := spent / n if n > 0 else 0
		var worth := 0
		for e in Game.collection:
			worth += PrizeCatalog.cost(e["id"])
		collection_stats.text = "획득 %d개 · 도전 %d판 · 쓴 돈 %s · 1개당 평균 %s · 상품 원가 합계 %s" % [
			n, int(Game.stats["plays"]), Game.won(spent), Game.won(avg), Game.won(worth)]


func open_inspector(entry_index: int) -> void:
	if collection_panel.visible:
		collection_panel.visible = false
	inspector.open_entry(entry_index)


func _toggle_owner() -> void:
	if pause_panel.visible or collection_panel.visible:
		return
	var on := not owner_panel.visible
	owner_panel.visible = on
	Game.set_owner_mode(on)
	if not on and shop:
		shop.save_all()
	if on:
		owner_panel.open_for(player.machine if player.mode == Player.Mode.MACHINE else player.focus)
	if player:
		player.set_ui_open(on)
