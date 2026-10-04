extends SceneTree
func _initialize():
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main); current_scene = main
	await process_frame
	var p = main.player
	for k in 30: await physics_frame
	var m = main.shop.machines[0]
	p.enter_machine(m)
	printerr("target ", m.front_cam.global_position)
	for k in 120:
		await physics_frame
		if k % 20 == 0: printerr(k, " cam=", p.camera.global_position, " mode=", p.mode)
	quit()
