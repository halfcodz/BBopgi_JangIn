extends SceneTree
## 사장 모드 화면 스크린샷
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	get_root().disable_3d = true
	for k in 240:
		await physics_frame
	var player = main.player
	var m = main.shop.machines[1]
	player.enter_machine(m)
	for k in 90:
		await physics_frame
	main.hud._toggle_owner()
	for tab in [0, 2, 3]:
		main.hud.owner_panel.tabs.current_tab = tab
		get_root().disable_3d = false
		for k in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s_%d.png" % [out, tab])
		get_root().disable_3d = true
	quit()
