extends SceneTree
## 개발용: 상품을 바닥에 떨어뜨려 놓고 스크린샷을 찍는다.
## godot --path . -s tests/preview_prizes.gd -- out.png id1 id2 ...

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var ids := args.slice(1)
	var root := Node3D.new()
	get_root().add_child(root)
	await process_frame

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.85, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 1.0)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.ssao_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.4
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-0.6, 0.8, 1.0)
	fill.omni_range = 4
	fill.light_energy = 0.6
	root.add_child(fill)

	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6, 0.1, 6)
	fs.shape = bs
	fs.position.y = -0.05
	floor_body.add_child(fs)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	fm.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.75, 0.75, 0.78)
	fm.material_override = fmat
	floor_body.add_child(fm)
	root.add_child(floor_body)

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := ids.size()
	var spacing := float(OS.get_environment("SPACING")) if OS.get_environment("SPACING") != "" else 0.36
	for i in n:
		var p := PrizeFactory.create(ids[i], rng, i % 4)
		root.add_child(p)
		p.position = Vector3((i - (n - 1) * 0.5) * spacing, 0.0, 0.0)
		if OS.get_environment("FREEZE") != "":
			p.set_frozen(true)
	var cam := Camera3D.new()
	root.add_child(cam)
	var settle := float(OS.get_environment("SETTLE")) if OS.get_environment("SETTLE") != "" else 0.0
	var dist := 0.35 + n * 0.17
	var cp := Vector3(0, 0.22 + dist * 0.25, dist)
	if OS.get_environment("CAM") != "":
		var c := OS.get_environment("CAM").split(",")
		cp = Vector3(float(c[0]), float(c[1]), float(c[2]))
	var tgt_y := float(OS.get_environment("TY")) if OS.get_environment("TY") != "" else 0.12
	cam.look_at_from_position(cp, Vector3(0, tgt_y, 0))
	cam.fov = 40
	if settle > 0:
		for k in int(settle * 60):
			await physics_frame
	for k in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
