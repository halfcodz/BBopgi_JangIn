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
var mp_keys: Label
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

	# 기계 조작 패널
	machine_panel = PanelContainer.new()
	machine_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	machine_panel.position = Vector2(-470, -250)
	machine_panel.custom_minimum_size = Vector2(450, 200)
	machine_panel.visible = false
	root.add_child(machine_panel)
	var mv := VBoxContainer.new()
	machine_panel.add_child(mv)
	var mh := HBoxContainer.new()
	mv.add_child(mh)
	mp_name = UIKit.title("", 24)
	mh.add_child(mp_name)
	mp_info = UIKit.label("", 18, UIKit.PINK_DARK)
	mv.add_child(mp_info)
	mp_state = UIKit.label("", 21)
	mp_state.autowrap_mode = TextServer.AUTOWRAP_WORD
	mv.add_child(mp_state)
	mp_keys = UIKit.label("", 15)
	mp_keys.autowrap_mode = TextServer.AUTOWRAP_WORD
	mv.add_child(mp_keys)

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
	if player and player.mode == Player.Mode.MACHINE and player.machine:
		var m: ClawMachine = player.machine
		mp_name.text = String(m.settings.get("name", "인형뽑기"))
		mp_info.text = "%s   ·   남은 판 %d" % [m.price_text().replace("\n", " · "), m.credits]
		var bin_n := m.prizes_in_bin().size()
		mp_state.text = m.state_text() + ("   🎁 배출구에 %d개! [E] 꺼내기" % bin_n if bin_n > 0 else "")
		if Game.owner_mode:
			mp_state.text += "   (강집게: %s)" % ("다음 판 ON" if _next_strong(m) else "OFF")
		if String(m.settings["control_mode"]) == "2button":
			mp_keys.text = "[B] 1,000원  [N] 5,000원\n[X 누르는 동안] → 오른쪽   [Space 누르는 동안] ↑ 안쪽 (떼면 하강)\n[C] 시점  [E] 꺼내기  [Q] 나가기"
		else:
			mp_keys.text = "[B] 1,000원  [N] 5,000원\n[WASD/방향키] 조이스틱   [Space] 집게 내리기\n[C] 정면/비스듬히/가까이  [마우스] 고개  [E] 꺼내기  [Q] 나가기"
	elif player and player.mode == Player.Mode.WALK and player.focus and player.focus.has_method("interact_prompt"):
		prompt.text = player.focus.interact_prompt()
	if Input.is_action_just_pressed("help"):
		help_panel.visible = not help_panel.visible
	if Input.is_action_just_pressed("collection") and not owner_panel.visible:
		_toggle_collection()
	if Input.is_action_just_pressed("owner_mode"):
		_toggle_owner()
	if Input.is_action_just_pressed("leave") and player and player.mode == Player.Mode.WALK:
		if collection_panel.visible:
			_toggle_collection()
		elif owner_panel.visible:
			_toggle_owner()
		else:
			_toggle_pause()


func _next_strong(m: ClawMachine) -> bool:
	match String(m.settings["payout_mode"]):
		"count":
			return int(m.ledger["plays_since_payout"]) + 1 >= int(m.settings["payout_every"])
		"revenue":
			return int(m.ledger["revenue_since_payout"]) + 1000 / int(m.settings["plays_per_1000"]) >= int(m.settings["payout_revenue"])
	return false


func show_toast(text: String) -> void:
	var p := PanelContainer.new()
	var l := UIKit.label(text, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	p.add_child(l)
	toast_box.add_child(p)
	if toast_box.get_child_count() > 4:
		toast_box.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


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
	var txt := """[걷기] WASD 이동 · Shift 달리기 · 마우스 둘러보기 · E 상호작용
[인형뽑기] 기계 앞에서 E → B로 1,000원(N은 5,000원) 넣기 → 시간 안에 조이스틱 이동 → Space로 집게 내리기
  · C: 정면 / 옆 / 가까이 시점 전환 — 옆에서 보면 집게가 앞뒤로 어디 있는지 보여요!
  · 집게는 줄에 매달려 흔들립니다. 멈춘 뒤 흔들림이 잦아들 때 내리세요.
  · 인형이 배출구로 떨어지면 E로 꺼내세요. 꺼낸 인형은 '나의 전시장'에 진열됩니다.
[큰 기계] 1회 1,000원 · 3발 큰 집게   [작은 기계] 1,000원 2회 · 작은 집게(2발/3발)
[2버튼 기계] X를 누르는 동안 오른쪽, Space를 누르는 동안 안쪽 → 떼면 바로 내려갑니다.
[지폐교환기] 10,000원·5,000원권을 1,000원권으로 바꿔 줍니다.
[캡슐뽑기] 동전/지폐를 넣고 손잡이를 돌려 캡슐을 뽑아요.
[사장 모드] F1(또는 Tab, 카운터에서 E) — 기계별 집게 힘(잡을 때/올라갈 때/정상/이동),
  강집게 확률(N판마다·매출 기준), 타이머, 가격, 조작 방식, 발 개수, 흔들림, 상품 진열(클릭해서 놓기)과 매출 장부까지!
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
			collection_grid.add_child(UIKit.label("%s  x%d" % [PrizeCatalog.display_name(id), counts[id]], 20))
		var n := Game.collection.size()
		var spent := int(Game.stats["spent"])
		var avg := spent / n if n > 0 else 0
		var worth := 0
		for e in Game.collection:
			worth += PrizeCatalog.cost(e["id"])
		collection_stats.text = "획득 %d개 · 도전 %d판 · 쓴 돈 %s · 1개당 평균 %s · 상품 원가 합계 %s" % [
			n, int(Game.stats["plays"]), Game.won(spent), Game.won(avg), Game.won(worth)]


func _toggle_owner() -> void:
	if pause_panel.visible or collection_panel.visible:
		return
	var on := not owner_panel.visible
	owner_panel.visible = on
	Game.set_owner_mode(on)
	if on:
		owner_panel.open_for(player.machine if player.mode == Player.Mode.MACHINE else player.focus)
	if player:
		player.set_ui_open(on)
