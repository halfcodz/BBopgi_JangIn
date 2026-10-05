extends SceneTree
func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	await process_frame
	var player = main.player
	player.global_position = Vector3(2.4, 0.05, 3.6)
	for k in 720:
		await physics_frame
	var cam: Camera3D = player.camera
	var cats := {}
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is GeometryInstance3D) or not n.is_visible_in_tree():
			continue
		var gi: GeometryInstance3D = n
		var aabb: AABB = gi.global_transform * gi.get_aabb()
		var c := aabb.get_center()
		var d := cam.global_position.distance_to(c)
		if gi.visibility_range_begin > 0.0 and d < gi.visibility_range_begin:
			continue
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end:
			continue
		if not cam.is_position_in_frustum(c) and aabb.size.length() < 2.0:
			continue
		var cat := "기타"
		var p: Node = n
		while p:
			var sc = p.get_script()
			if sc:
				cat = String(sc.get_global_name())
				if cat in ["Prize", "ClawRig", "ClawMachine", "BridgeMachine", "Shop", "VendingMachine", "GachaMachine", "Showcase", "BillChanger", "OwnerCounter"]:
					break
			p = p.get_parent()
		var surf := 1
		if gi is MeshInstance3D and gi.mesh:
			surf = gi.mesh.get_surface_count()
		var key: String = cat + " " + gi.get_class()
		cats[key] = int(cats.get(key, 0)) + surf
	var tot := 0
	for k in cats:
		tot += cats[k]
	var keys := cats.keys()
	keys.sort_custom(func(a, b): return cats[a] > cats[b])
	for k in keys:
		printerr(k, " = ", cats[k])
	printerr("합계 ", tot)
	quit()
