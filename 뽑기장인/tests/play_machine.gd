extends SceneTree
## 자동 플레이 테스트: play_machine.gd -- kind rounds [shot_prefix] [power_override]
## 매 판 가장 가까운 인형 머리 위로 이동해 집기 → 결과 통계

var m


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[0] if args.size() > 0 else "big"
	var rounds := int(args[1]) if args.size() > 1 else 5
	var shot := args[2] if args.size() > 2 else ""
	var power := int(args[3]) if args.size() > 3 else -1
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.18, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.85, 1.0)
	e.ambient_light_energy = 0.4
	env.environment = e
	root.add_child(env)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.6, 1.8)
	l.omni_range = 8
	root.add_child(l)
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(10, 0.1, 10)
	cs.shape = bs
	cs.position.y = -0.05
	fb.add_child(cs)
	root.add_child(fb)
	var game = root.get_node("/root/Game")
	game.machine_settings.erase("play_" + kind)
	game.machine_prizes.erase("play_" + kind)
	m = load("res://scripts/machine/bridge_machine.gd" if kind == "bridge" else "res://scripts/machine/claw_machine.gd").new()
	m.kind = kind
	m.machine_id = "play_" + kind
	m.initial_fill = 16 if kind == "big" else (1 if kind == "bridge" else 20)
	root.add_child(m)
	if power >= 0:
		for k in ["power_grab", "power_lift", "power_top", "power_carry"]:
			m.settings[k] = power
		m.settings["payout_mode"] = "skill"
	m.settings["control_mode"] = "joystick"
	var cam: Camera3D = null
	if shot != "":
		cam = Camera3D.new()
		root.add_child(cam)
		cam.global_transform = m.close_cam.global_transform
		cam.fov = 55
		get_root().disable_3d = true
	for k in 360:
		await physics_frame
		if k % 120 == 0:
			printerr("settle ", k, " t=", Time.get_ticks_msec())
	var wins := 0
	var lifted := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for r in rounds:
		game.give_money("1000", 1)
		m.insert_bill("1000")
		while m.state != 1:
			await physics_frame
		# 목표: 배출구에서 먼 인형 하나(머리 쪽)
		var target: Vector3
		var alive := 0
		for q in m.get_prizes():
			if not q.won:
				alive += 1
		if alive == 0:
			m.fill_random(1)
			for k in 180:
				await physics_frame
		var best := INF
		var prizes: Array = m.get_prizes()
		var tp = null
		for p in prizes:
			if p.won:
				continue
			var c: Vector3 = m.to_local(p.get_center())
			var d := Vector2(c.x - m._home().x, c.z - m._home().z).length()
			var score := rng.randf()
			if OS.get_environment("TARGET") != "" and p.prize_id != OS.get_environment("TARGET"):
				score += 10.0
			if score < best:
				best = score
				tp = p
		var hb = tp.bodies[1] if tp.bodies.size() > 1 else tp.bodies[0]
		target = m.to_local(hb.global_position)
		if kind == "bridge":
			target.x += 0.1 * (1 if rng.randf() < 0.5 else -1)

		var start_y: float = tp.get_center().y
		# 캐리지를 목표 위로
		var t := 0.0
		while t < 20.0:
			var d := Vector2(target.x - m.carriage.x, target.z - m.carriage.z)
			if d.length() < 0.012:
				m.set_input(Vector2.ZERO)
				if m.carriage_vel.length() < 0.01:
					break
			else:
				var v: Vector2 = d.normalized() * clampf(d.length() / 0.08, 0.2, 1.0)
				m.set_input(v)
			await physics_frame
			t += 1.0 / 120.0
		m.set_input(Vector2.ZERO)
		for k in 60:
			await physics_frame
		m.press_drop()
		var max_y := start_y
		var shot_done := false
		var logged := false
		while m.state != 0:
			await physics_frame
			if not logged and m.state == 4 and m.phase_t > 0.7:
				logged = true
				printerr("grab: head_y=%.3f closed=%.2f target_top=%.3f" % [m.head_y, m.claw.closedness(), tp.highest_y() if is_instance_valid(tp) else -1.0])
			max_y = max(max_y, tp.get_center().y if is_instance_valid(tp) else max_y)
			if cam and not shot_done and m.state == 4 and m.phase_t > 0.6:
				shot_done = true
				get_root().disable_3d = false
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png("%s_%d.png" % [shot, r])
				get_root().disable_3d = true
		if max_y > start_y + 0.15:
			lifted += 1
		var w: int = m.prizes_in_bin().size()
		if w > 0:
			wins += 1
			m.take_prizes_from_bin()
		printerr("land head_y=%.3f base=%.3f" % [m.head_y, m.base_h])
		print("round %d: target=%s lifted=%.2f strong=%s bin=%d" % [r, tp.prize_id if is_instance_valid(tp) else "?", max_y - start_y, m.strong, w])
	print("RESULT kind=%s rounds=%d lifted=%d wins=%d" % [kind, rounds, lifted, wins])
	quit()
