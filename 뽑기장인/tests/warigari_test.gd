extends SceneTree
## 와리가리 검증: 큰 기계는 박자 맞춰 좌우로 흔들면 흔들림이 커지고, 흔들리는 채로 내려가 인형 더미에 파고든다.
## 작은 기계는 같은 조작에도 거의 흔들리지 않는다.
## 실행: godot --headless --fixed-fps 120 -s tests/warigari_test.gd


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	for k in 600:
		await physics_frame
	for idx in [0, 6]:
		await _try(main, main.shop.machines[idx])
	quit()


func _try(main, m) -> void:
	var player = main.player
	player.enter_machine(m)
	await physics_frame
	m.credits = 1
	m._start_game()
	for k in 60:
		await physics_frame
	# 흔들림 방향을 따라 레일을 밀어 준다(실제 와리가리: 집게가 가는 쪽으로 같이 밀기)
	var maxa := 0.0
	var t := 0
	Input.action_press("move_forward")
	for k in 40:
		await physics_frame
	Input.action_release("move_forward")
	var L: float = m.rail_y - 0.06 - (m.head_y + m.claw.head_height)
	for k in 720:
		var dir := "move_right" if (m.sway_v.x < 0.0 or (k < 10)) else "move_left"
		# 캐리지 가속도 반대로 집게가 흔들리므로, 집게가 오른쪽(+x)으로 가는 중엔 왼쪽으로 당긴다
		Input.action_release("move_right")
		Input.action_release("move_left")
		Input.action_press(dir)
		await physics_frame
		maxa = maxf(maxa, absf(m.sway.x))
	Input.action_release("move_right")
	Input.action_release("move_left")
	printerr("[%s] 줄 길이 %.2fm  흔든 뒤 최대 각도 %.1f°  흔들림 폭 ±%.1fcm" % [m.kind, L, rad_to_deg(maxa), sin(maxa) * L * 100.0])
	# 끝에 왔을 때 하강
	for k in 240:
		await physics_frame
		if absf(m.sway_v.x) < 0.08 and absf(m.sway.x) > maxa * 0.6:
			break
	var at_drop: float = m.sway.x
	Input.action_press("claw_drop")
	await physics_frame
	Input.action_release("claw_drop")
	var land_off := 0.0
	var dig := 0.0
	var first_touch_y := -1.0
	for k in 900:
		await physics_frame
		if m.state == m.State.DESCENDING:
			var off: float = m.to_local(m.claw.head.global_position).x - m.carriage.x
			land_off = maxf(land_off, absf(off))
			if first_touch_y < 0.0 and (m.claw.touching_prize() or m.claw.head_blocked(0.006)):
				first_touch_y = m.head_y
		if m.state == m.State.GRABBING:
			break
	if first_touch_y > 0.0:
		dig = first_touch_y - m.head_y
	printerr("[%s] 내릴 때 각도 %.1f°  내려가며 흔들린 최대 폭 %.1fcm  처음 닿은 뒤 파고든 깊이 %.1fcm" % [m.kind, rad_to_deg(at_drop), land_off * 100.0, dig * 100.0])
	for k in 2400:
		await physics_frame
		if m.state == m.State.IDLE:
			break
	player.leave_machine() if player.has_method("leave_machine") else null
	for k in 30:
		await physics_frame
