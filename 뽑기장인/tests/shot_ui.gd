extends SceneTree
## 사장 모드(쉬운 설정) + 확대 보기 화면 스크린샷
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	var game = get_root().get_node("/root/Game")
	game.add_to_collection("shiba", 0, "big_1")
	game.add_to_collection("panda", 0, "big_3")
	get_root().disable_3d = true
	for k in 240:
		await physics_frame
	var player = main.player
	player.enter_machine(main.shop.machines[0])
	for k in 60:
		await physics_frame
	main.hud._toggle_owner()
	for tab in [0, 1, 2]:
		main.hud.owner_panel.tabs.current_tab = tab
		await _snap("%s_owner%d.png" % [out, tab])
	main.hud._toggle_owner()
	main.hud.open_inspector(0)
	for k in 30:
		await process_frame
	await _snap("%s_insp.png" % out)
	quit()


func _snap(path: String) -> void:
	get_root().disable_3d = false
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
	get_root().disable_3d = true
