extends SceneTree
## 헤드리스 물리 보정 테스트: 집게 힘(%)에 따라 인형이 잡히는지 확인
## godot --headless --path . -s tests/test_claw.gd -- <prize_id> <size> <prongs> <offset_x> <powers...>

var results := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var pid := args[0] if args.size() > 0 else "bear"
	var size := float(args[1]) if args.size() > 1 else 1.0
	var pc := int(args[2]) if args.size() > 2 else 3
	var off := float(args[3]) if args.size() > 3 else 0.0
	var powers := []
	for i in range(4, args.size()):
		powers.append(float(args[i]))
	if powers.is_empty():
		powers = [0.15, 0.3, 0.5, 0.75, 1.0]
	for pw in powers:
		await _trial(pid, size, pc, off, pw)
	for r in results:
		print(r)
	quit()


func _trial(pid: String, size: float, pc: int, off: float, power: float) -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3, 0.1, 3)
	fs.shape = bs
	fs.position.y = -0.05
	floor_body.add_child(fs)
	root.add_child(floor_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var prize := PrizeFactory.create(pid, rng, 0)
	root.add_child(prize)
	for k in 90:
		await physics_frame
	#print("settled y=", prize.get_center(), " bodies=", prize.bodies.size())
	var claw := ClawRig.new()
	claw.size = size
	claw.prong_count = pc
	claw.position = Vector3(0, 0.8, 0)
	if OS.get_environment("MT") != "":
		claw.max_torque = float(OS.get_environment("MT"))
	root.add_child(claw)
	await physics_frame
	var c := prize.get_center()
	var pos := Vector3(c.x + off, 0.6, c.z)
	claw.open()
	claw.snap_all(Transform3D(Basis(), pos))
	for k in 60:
		claw.move_head(Transform3D(Basis(), pos), pos + Vector3.UP * 0.5)
		await physics_frame
	var c0 := claw.closedness()
	# 하강
	var dt := 1.0 / 120.0
	var touch := 0
	var extra := -1.0
	while pos.y > 0.0:
		pos.y -= 0.14 * dt
		claw.move_head(Transform3D(Basis(), pos), pos + Vector3.UP * 0.5)
		await physics_frame
		if claw.head_blocked() or claw.touching_anything() > 1:
			touch += 1
		if touch > 2 and extra < 0:
			extra = 0.012 * size
		if extra >= 0:
			extra -= 0.14 * dt
			if extra <= 0:
				break
	var land_y := pos.y
	#print("landed prize=", prize.get_center())
	claw.close(power)
	for k in 110:
		claw.move_head(Transform3D(Basis(), pos), pos + Vector3.UP * 0.5)
		await physics_frame
	var c1 := claw.closedness()
	#print("closed prize=", prize.get_center(), " prong0=", claw.prongs[0].global_position)
	# 상승
	while pos.y < 0.6:
		pos.y += 0.12 * dt
		claw.move_head(Transform3D(Basis(), pos), pos + Vector3.UP * 0.5)
		await physics_frame
	for k in 240:
		claw.move_head(Transform3D(Basis(), pos), pos + Vector3.UP * 0.5)
		await physics_frame
	var lifted := prize.get_center().y
	results.append("%s power=%.2f open=%.2f closed=%.2f land=%.3f prize_y=%.3f %s" % [pid, power, c0, c1, land_y, lifted, "잡힘" if lifted > 0.3 else "놓침"])
	root.queue_free()
	await process_frame
