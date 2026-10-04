extends SceneTree
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	get_root().disable_3d = true
	for k in 300:
		await physics_frame
	var player = main.player
	for mi in [19, 21]:
		player.enter_machine(main.shop.machines[mi])
		for v in [0, 1]:
			for k in 90:
				await physics_frame
			get_root().disable_3d = false
			for k in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("%s_%d_%d.png" % [out, mi, v])
			get_root().disable_3d = true
			player.cycle_view()
		player.leave_machine()
		for k in 20:
			await physics_frame
	quit()
