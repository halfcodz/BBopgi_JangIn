extends SceneTree
## 일본식 다리 기계 물리 실험: bridge_lab.gd -- strategy plays [shot_prefix]
## strategy: corner(뒤 모서리를 한쪽 팔로, 좌우 번갈아) / end(상자 끝을 가운데로) / random

var m


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var strategy := args[0] if args.size() > 0 else "corner"
	var plays := int(args[1]) if args.size() > 1 else 10
	var shot := args[2] if args.size() > 2 else ""
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var game = root.get_node("/root/Game")
	game.machine_settings.erase("lab")
	game.machine_prizes.erase("lab")
	m = load("res://scripts/machine/bridge_machine.gd").new()
	m.kind = "bridge"
	m.machine_id = "lab"
	m.initial_fill = 1
	var ov := OS.get_environment("LAB_SET")
	if ov != "":
		m.preset = JSON.parse_string(ov)
	root.add_child(m)
	m.settings["control_mode"] = "joystick"
	var cam: Camera3D = null
	if shot != "":
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.2, 0.2, 0.25)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(1, 1, 1)
		e.ambient_light_energy = 0.6
		env.environment = e
		root.add_child(env)
		cam = Camera3D.new()
		root.add_child(cam)
		var cp := Vector3(0.55, 1.35, 0.75)
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, 1.0, 0) - cp), cp)
		cam.fov = 50
	get_root().disable_3d = true
	for k in 240:
		await physics_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 3
	var wins := 0
	var first_win := -1
	var side := 1.0
	var r := 0
	while r < plays:
		var boxes: Array = []
		for q in m.get_prizes():
			if not q.won:
				boxes.append(q)
		if boxes.is_empty():
			m.fill_random(1)
			for k in 200:
				await physics_frame
			continue
		r += 1
		var tp = boxes[0]
		var b: RigidBody3D = tp.bodies[0]
		var c: Vector3 = m.to_local(b.global_position)
		# 상자의 긴 축(앞뒤)을 찾는다
		var bl: Basis = m.global_transform.basis.inverse() * b.global_transform.basis
		var ax := Vector3.ZERO
		var best := 0.0
		for v in [bl.x, bl.y, bl.z]:
			if absf(v.z) > best:
				best = absf(v.z)
				ax = v
		var tgt := Vector3(c.x, 0, c.z)
		match strategy:
			"corner":
				tgt.x = c.x + side * 0.075
				tgt.z = c.z - 0.11
				side = -side
			"end":
				tgt.z = c.z + side * 0.12
				side = -side
			"fixed":
				var a: PackedStringArray = OS.get_environment("AIM").split(",")
				tgt.x = c.x + float(a[0])
				tgt.z = c.z + float(a[1])
			"smart":
				# 상자가 기울어 있으면 들린 쪽 끝을 눌러 세우고, 아니면 한 방향으로 계속 민다
				var up_y := absf(bl.z.y)
				if up_y < 0.995:
					var e1: Vector3 = c + ax * 0.13
					var e2: Vector3 = c - ax * 0.13
					var hi: Vector3 = e1 if e1.y > e2.y else e2
					tgt.z = hi.z
				else:
					tgt.z = c.z + 0.12
			"smart2":
				# 사람처럼: 상자 중심이 봉 사이 한쪽(|z| 0.05~0.09)에 오도록 밀고, 들린 끝은 눌러서 세운다
				var e1b: Vector3 = c + bl.x * 0.13  # 상자 긴 변(모델 X축)
				var e2b: Vector3 = c - bl.x * 0.13
				var hib: Vector3 = e1b if e1b.y > e2b.y else e2b
				if c.z < -0.085:
					tgt.z = c.z - 0.12  # 뒤 끝을 들어 앞으로
				elif c.z > 0.085:
					tgt.z = c.z + 0.12  # 앞 끝을 들어 뒤로
				elif absf(bl.z.y) < 0.8:
					# 크게 기운 상자: 위쪽 끝을 아래쪽 끝 위로 밀어 세운다(각 누르기)
					var lob: Vector3 = e2b if e1b.y > e2b.y else e1b
					tgt.z = hib.z + signf(lob.z - hib.z) * 0.035 + rng.randf_range(-0.01, 0.01)
				elif absf(bl.z.y) < 0.995:
					tgt.z = hib.z  # 들린 끝 들기
				else:
					tgt.z = c.z + 0.12
			"push":
				tgt.z = c.z + 0.12
			"pushback":
				tgt.z = c.z - 0.12
			"center":
				tgt.z = c.z + 0.05
			"random":
				tgt.x = c.x + rng.randf_range(-0.12, 0.12)
				tgt.z = c.z + rng.randf_range(-0.17, 0.17)
		game.give_money("1000", 1)
		m.insert_bill("1000")
		m._start_game()  # 돈만 넣으면 기다림 → 조작 시작과 같게
		while m.state != 1:
			await physics_frame
		var t := 0.0
		while t < 20.0:
			var d := Vector2(tgt.x - m.carriage.x, tgt.z - m.carriage.z)
			if d.length() < 0.008:
				m.set_input(Vector2.ZERO)
				if m.carriage_vel.length() < 0.01:
					break
			else:
				m.set_input(d.normalized() * clampf(d.length() / 0.08, 0.15, 1.0))
			await physics_frame
			t += 1.0 / 120.0
		m.set_input(Vector2.ZERO)
		for k in 90:
			await physics_frame
		m.press_drop()
		var shot_n := 0
		var maxlift := 0.0
		var y0: float = b.global_position.y if is_instance_valid(b) else 0.0
		var cross := ""
		while m.state != 0:
			await physics_frame
			if is_instance_valid(b):
				maxlift = maxf(maxlift, b.global_position.y - y0)
				var lc: Vector3 = m.to_local(b.global_position)
				if cross == "" and lc.y < m.bar_y - 0.08:
					var lb: Basis = m.global_transform.basis.inverse() * b.global_transform.basis
					cross = " 통과: z=%.3f 장축 기울기(수직=90)=%.0f" % [lc.z, rad_to_deg(asin(absf(lb.x.y)))]
			if cam and r < 4 and OS.get_environment("SHOTALL") == "" and m.state >= 4 and Engine.get_physics_frames() % 20 == 0 and shot_n < 16:
				get_root().disable_3d = false
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png("%s_%d_%d.png" % [shot, r - 1, shot_n])
				shot_n += 1
				get_root().disable_3d = true
		for k in 120:
			await physics_frame
		if cam and (r <= 2 or OS.get_environment("SHOTALL") != ""):
			get_root().disable_3d = false
			var cp2: Vector3 = m.to_global(Vector3(0.62, 1.12, 0.0))
			cam.global_transform = Transform3D(Basis.looking_at(m.to_global(Vector3(0.0, 1.0, 0.0)) - cp2), cp2)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("%s_end_%d.png" % [shot, r - 1])
			get_root().disable_3d = true
			var cp := Vector3(0.55, 1.35, 0.75)
			cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, 1.0, 0) - cp), cp)
		var won: bool = m.prizes_in_bin().size() > 0
		var pose := "gone"
		if is_instance_valid(b):
			var c2: Vector3 = m.to_local(b.global_position)
			var bl2: Basis = m.global_transform.basis.inverse() * b.global_transform.basis
			pose = "c=(%.3f,%.3f,%.3f) up=(%.2f,%.2f,%.2f)" % [c2.x, c2.y, c2.z, bl2.z.x, bl2.z.y, bl2.z.z]
		if cross != "":
			printerr(cross)
		printerr("play %d aim=(%.3f,%.3f) maxlift=%.3f won=%s %s" % [r - 1, tgt.x - c.x, tgt.z - c.z, maxlift, won, pose])
		if won:
			wins += 1
			if first_win < 0:
				first_win = r
			m.take_prizes_from_bin()
	printerr("RESULT strategy=%s plays=%d wins=%d first_win=%d" % [strategy, plays, wins, first_win])
	quit()
