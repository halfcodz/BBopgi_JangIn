extends SceneTree
func _initialize():
	var out = OS.get_cmdline_user_args()[0]
	var root = Node3D.new(); get_root().add_child(root); await process_frame
	var sc = load("res://assets/prizes/bear.glb").instantiate(); root.add_child(sc)
	var m = StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi in sc.find_children("*", "MeshInstance3D", true, false): mi.material_override = m
	var cam = Camera3D.new(); root.add_child(cam); cam.look_at_from_position(Vector3(0.0,0.25,0.5), Vector3(0,0.17,0))
	for k in 6: await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out); quit()
