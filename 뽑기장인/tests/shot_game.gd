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
		["entrance", Vector3(2.2, 0.05, 3.3), 0.25, -0.12],
		["machines", Vector3(-1.0, 0.05, -1.2), 0.0, -0.05],
		["small", Vector3(-3.0, 0.05, -1.2), 1.4, -0.12],
		["showcase", Vector3(2.4, 0.05, -1.0), -0.45, 0.0],
		["side", Vector3(3.2, 0.05, 1.8), -1.35, -0.1],
		["counter", Vector3(-2.8, 0.05, 1.6), 2.6, -0.2],
		["bridge", Vector3(-2.6, 0.05, 1.7), PI / 2, -0.12],
	]
	get_root().disable_3d = true
	for k in 360:
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
		get_root().disable_3d = true
	# 플레이 화면(큰 기계: 4가지 시점) + 피규어 기계
	for mi in [0, 8]:
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
			if mi == 8:
				break
		player.leave_machine()
		for k in 30:
			await physics_frame
	quit()
