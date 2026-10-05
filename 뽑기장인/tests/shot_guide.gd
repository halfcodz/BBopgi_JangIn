extends SceneTree
## 일본식 기계 공략 도우미 화면: shot_guide.gd -- out.png
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	get_root().disable_3d = true
	for k in 300:
		await physics_frame
	var game = get_root().get_node("/root/Game")
	var m = main.shop.machines[19]
	main.player.enter_machine(m)
	game.give_money("1000", 1)
	m.insert_bill("1000")
	for k in 240:
		await physics_frame
	get_root().disable_3d = false
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
