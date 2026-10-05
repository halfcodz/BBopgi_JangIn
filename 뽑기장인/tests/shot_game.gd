extends SceneTree
## 실제 게임 장면 스크린샷: shot_game.gd -- out_prefix
## 여러 위치에서 찍는다(입구, 큰 기계, 작은 기계, 전시장, 플레이 화면)

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	var player = main.player
	var shots := [
		["entrance", Vector3(2.2, 0.05, 4.4), 0.35, -0.12],
		["machines", Vector3(-2.6, 0.05, -2.6), 0.0, -0.05],
		["goods", Vector3(-2.5, 0.05, 0.6), 0.0, -0.22],
		["small", Vector3(-4.6, 0.05, -2.4), 1.4, -0.12],
		["showcase", Vector3(4.0, 0.05, -1.4), -0.1, 0.0],
		["gallery", Vector3(5.0, 0.05, -5.4), 0.0, -0.08],
		["gallery_back", Vector3(4.8, 0.05, -9.5), PI, -0.05],
		["vending", Vector3(4.7, 0.05, 3.6), -PI / 2, -0.2],
		["vending_close", Vector3(5.85, 0.05, 3.35), -PI / 2, -0.3],
		["center", Vector3(2.4, 0.05, 3.6), 0.0, -0.12],
		["bridge", Vector3(-3.6, 0.05, 1.9), PI / 2, -0.12],
	]
	# SHOTS=entrance,center 처럼 일부만 / PLAYS=0,19 처럼 플레이 화면 기계 번호
	var only := OS.get_environment("SHOTS")
	if only != "":
		var keep := []
		for s0 in shots:
			if only.split(",").has(s0[0]):
				keep.append(s0)
		shots = keep
	var plays := [0, 19, 10]
	if OS.get_environment("PLAYS") != "":
		plays = []
		for t in OS.get_environment("PLAYS").split(","):
			plays.append(int(t))
	get_root().disable_3d = true
	var wait := int(OS.get_environment("WAIT")) if OS.get_environment("WAIT") != "" else 360
	for k in wait:
		await physics_frame
	for s in shots:
		player.global_position = s[1]
		player._yaw = s[2]
		player.rotation.y = s[2]
		player._pitch = s[3]
		player.head.rotation.x = s[3]
		get_root().disable_3d = false
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s_%s.png" % [out, s[0]])
		printerr("[%s] 그리기 호출 %d, 물체 %d, 정점 %d" % [s[0], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		get_root().disable_3d = true
	# 플레이 화면(큰 기계: 4가지 시점) + 피규어 기계
	for mi in plays:
		var m = main.shop.machines[mi]
		player.enter_machine(m)
		for v in 4:
			for k in 90:
				await physics_frame
			get_root().disable_3d = false
			for k in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("%s_play%d_%d.png" % [out, mi, v])
			get_root().disable_3d = true
			player.cycle_view()
			if mi != 0:
				break
		player.leave_machine()
		for k in 30:
			await physics_frame
	quit()
