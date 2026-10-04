extends SceneTree
## 다리 기계: 상자를 여러 기울기로 봉 사이에 세워 두고 빠지는지/걸리는지 확인 + 걸린 상자의 들린 끝을 눌러 보기
var m


func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var game = root.get_node("/root/Game")
	for ang in [float(OS.get_cmdline_user_args()[0])]:
		game.machine_settings.erase("jam")
		game.machine_prizes.erase("jam")
		m = load("res://scripts/machine/bridge_machine.gd").new()
		m.kind = "bridge"
		m.machine_id = "jam"
		m.initial_fill = 1
		root.add_child(m)
		m.settings["control_mode"] = "joystick"
		for k in 30:
			await physics_frame
		printerr("prizes ", m.get_prizes().size())
		var p = m.get_prizes()[0]
		var b: RigidBody3D = p.bodies[0]
		# 긴 변이 거의 세로가 되게(수직에서 ang 도) 봉 사이에 놓기: 아래 끝이 봉 높이보다 조금 아래
		var tilt := deg_to_rad(90.0 - ang)
		var basis: Basis = Basis(Vector3.RIGHT, tilt) * m.BOX_LAY
		var center := Vector3(0, m.bar_y + 0.02, 0)
		if OS.get_environment("FLATZ") != "":
			basis = m.BOX_LAY
			center = Vector3(0, m.bar_y + 0.077, float(OS.get_environment("FLATZ")))
		b.global_transform = m.global_transform * Transform3D(basis, center)
		b.linear_velocity = Vector3.ZERO
		m.game_active = true
		for k in 360:
			await physics_frame
		if OS.get_environment("SHOT") != "":
			var cam := Camera3D.new()
			root.add_child(cam)
			var cp: Vector3 = m.to_global(Vector3(0.7, 0.98, 0.0))
			cam.global_transform = Transform3D(Basis.looking_at(m.to_global(Vector3(0, 0.95, 0)) - cp), cp)
			cam.fov = 45
			var env := WorldEnvironment.new()
			var e := Environment.new()
			e.background_mode = Environment.BG_COLOR
			e.background_color = Color(0.3, 0.3, 0.35)
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.ambient_light_color = Color(1, 1, 1)
			env.environment = e
			root.add_child(env)
			for k in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(OS.get_environment("SHOT"))
			quit()
			return
		var c: Vector3 = m.to_local(b.global_position)
		printerr("tilt_from_vertical=%d -> y=%.3f won=%s" % [ang, c.y, m.prizes_in_bin().size() > 0])
		# 걸린 상자: 들린 끝을 눌러 보기(최대 6판)
		for play in 6:
			if m.prizes_in_bin().size() > 0 or not is_instance_valid(b):
				break
			var bl: Basis = m.global_transform.basis.inverse() * b.global_transform.basis
			var ax: Vector3 = bl.x
			var c0: Vector3 = m.to_local(b.global_position)
			var e1: Vector3 = c0 + ax * 0.13
			var e2: Vector3 = c0 - ax * 0.13
			var hi: Vector3 = e1 if e1.y > e2.y else e2
			var tz: float = hi.z + float(OS.get_environment("OFF") if OS.get_environment("OFF") != "" else "0")
			game.give_money("1000", 1)
			m.insert_bill("1000")
			while m.state != 1:
				await physics_frame
			var t := 0.0
			while t < 15.0:
				var d := Vector2(0.0 - m.carriage.x, tz - m.carriage.z)
				if d.length() < 0.006:
					m.set_input(Vector2.ZERO)
					if m.carriage_vel.length() < 0.01:
						break
				else:
					m.set_input(d.normalized() * clampf(d.length() / 0.08, 0.15, 1.0))
				await physics_frame
				t += 1.0 / 120.0
			m.set_input(Vector2.ZERO)
			for k in 60:
				await physics_frame
			m.press_drop()
			while m.state != 0:
				await physics_frame
			for k in 120:
				await physics_frame
			var c2: Vector3 = m.to_local(b.global_position) if is_instance_valid(b) else Vector3.ZERO
			printerr("  press play %d at z=%.3f (hi y=%.3f) -> y=%.3f up=%s won=%s" % [play, tz, hi.y, c2.y, str(bl.z.snapped(Vector3.ONE * 0.01)), m.prizes_in_bin().size() > 0])
		m.queue_free()
		await process_frame
	quit()
