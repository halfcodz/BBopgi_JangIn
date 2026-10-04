extends SceneTree
## UFO 집게 클로즈업: shot_claw.gd -- out_prefix
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.22, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	env.environment = e
	root.add_child(env)
	var game = root.get_node("/root/Game")
	game.machine_settings.erase("shotc")
	game.machine_prizes.erase("shotc")
	var m = load("res://scripts/machine/bridge_machine.gd").new()
	m.kind = "bridge"
	m.machine_id = "shotc"
	m.initial_fill = 1
	root.add_child(m)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40
	for k in 120:
		await physics_frame
	var h: Vector3 = m.claw.head.global_position
	var cp := h + Vector3(0.0, 0.02, 0.42)
	cam.global_transform = Transform3D(Basis.looking_at(h + Vector3(0, -0.04, 0) - cp), cp)
	await _shot(out + "_rest.png")
	cp = h + Vector3(0.25, 0.08, 0.32)
	cam.global_transform = Transform3D(Basis.looking_at(h + Vector3(0, -0.05, 0) - cp), cp)
	await _shot(out + "_rest_angle.png")
	m.claw.open()
	for k in 60:
		await physics_frame
	cp = h + Vector3(0.0, 0.02, 0.42)
	cam.global_transform = Transform3D(Basis.looking_at(h + Vector3(0, -0.06, 0) - cp), cp)
	await _shot(out + "_open.png")
	quit()


func _shot(path: String) -> void:
	for k in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
