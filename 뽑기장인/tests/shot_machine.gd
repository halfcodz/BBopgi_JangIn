extends SceneTree
## 기계 미리보기: shot_machine.gd -- out.png kind settle cam(front|side|close|far)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var kind := args[1] if args.size() > 1 else "big"
	var settle := float(args[2]) if args.size() > 2 else 3.0
	var view := args[3] if args.size() > 3 else "far"
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.18, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.85, 1.0)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	e.glow_enabled = true
	env.environment = e
	root.add_child(env)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.6, 1.8)
	l.omni_range = 8
	l.light_energy = 1.2
	root.add_child(l)
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(10, 0.1, 10)
	cs.shape = bs
	cs.position.y = -0.05
	fb.add_child(cs)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	fm.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = load("res://assets/textures/shop/floor_tiles.png")
	fmat.uv1_scale = Vector3(4, 4, 4)
	fm.material_override = fmat
	fb.add_child(fm)
	root.add_child(fb)
	var m = load("res://scripts/machine/claw_machine.gd").new()
	m.kind = kind
	m.machine_id = "test_" + kind
	m.initial_fill = 14 if kind == "big" else 18
	root.add_child(m)
	for k in int(settle * 120):
		await physics_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	match view:
		"front":
			cam.global_transform = m.front_cam.global_transform
		"side":
			cam.global_transform = m.side_cam.global_transform
		"close":
			cam.global_transform = m.close_cam.global_transform
		_:
			cam.look_at_from_position(Vector3(0.9, 1.7, 2.3), Vector3(0, 1.1, 0))
	cam.fov = 60
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
