extends SceneTree
## 키 입력으로 실제 플레이 흐름 검증 + 물리 부하 측정
func _press(a: String) -> void:
	Input.action_press(a)
	await physics_frame
	await process_frame
	Input.action_release(a)
	await physics_frame


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	for k in 960:
		await physics_frame
	var t0 := Time.get_ticks_usec()
	for k in 240:
		await physics_frame
	var per := (Time.get_ticks_usec() - t0) / 240.0 / 1000.0
	printerr("평균 프레임(물리 포함) %.2f ms, 물리 %.2f ms" % [per, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	var bodies := 0
	for m in main.shop.machines:
		for p in m.get_prizes():
			bodies += p.bodies.size()
	var sleeping := 0
	for m2 in main.shop.machines:
		for p in m2.get_prizes():
			for b in p.bodies:
				if b.sleeping: sleeping += 1
	printerr("상품 바디 수 ", bodies, " 잠든 바디 ", sleeping)
	var player = main.player
	var m = main.shop.machines[0]
	player.enter_machine(m)
	await physics_frame
	var cash0: int = main.get_node("/root/Game").cash_total()
	await _press("insert_1000")
	for k in 200:
		await physics_frame
	printerr("투입 후 상태=", m.state, " 크레딧=", m.credits, " 지갑 차감=", cash0 - main.get_node("/root/Game").cash_total())
	Input.action_press("move_right")
	Input.action_press("move_forward")
	for k in 150:
		await physics_frame
	Input.action_release("move_right")
	Input.action_release("move_forward")
	printerr("이동 후 캐리지=", m.carriage)
	await _press("toggle_view")
	await _press("claw_drop")
	var seen := {}
	for k in 3000:
		await physics_frame
		seen[m.state] = true
		if m.state == 0 and seen.size() > 3:
			break
	printerr("거친 상태들=", seen.keys(), " 최종=", m.state)
	await _press("interact")
	await _press("leave")
	printerr("나간 뒤 모드=", player.mode)
	# 사장 모드
	main.hud._toggle_owner()
	await process_frame
	printerr("사장 모드=", main.get_node("/root/Game").owner_mode)
	main.hud._toggle_owner()
	# 교환기
	var ch = null
	for c in main.shop.get_children():
		if c.has_method("interact") and c.get("lcd") != null: ch = c
	ch.interact(player)
	for k in 200:
		await physics_frame
	printerr("교환 후 지갑=", main.get_node("/root/Game").wallet)
	# 캡슐뽑기
	var g = null
	for c in main.shop.get_children():
		if c.has_method("interact") and c.get("tray_capsule") != null or (c.get("knob") != null and g == null): g = c
	g.interact(player)
	for k in 300:
		await physics_frame
	printerr("캡슐 트레이=", g.tray_capsule != null, " 위치=", g.tray_capsule.get_center() if g.tray_capsule else Vector3.ZERO, " 기계=", g.global_position)
	g.interact(player)
	await process_frame
	printerr("수집함=", main.get_node("/root/Game").collection.size())
	quit()
