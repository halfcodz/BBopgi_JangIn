extends SceneTree
## 게임 속도 설정 확인: 1.0배와 2.0배에서 한 판(내리기→집기→돌아오기)이 걸리는 실제 시간 비교
func _round(main, speed: float) -> float:
	var game = get_root().get_node("/root/Game")
	game.set_game_speed(speed)
	var m = main.shop.machines[0]
	main.player.enter_machine(m)
	m.credits = 1
	m._start_game()
	for k in 30:
		await process_frame
	m.press_drop()
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while m.state != 0 and frames < 20000:
		await process_frame
		frames += 1
	main.player.leave_machine()
	printerr("속도 %.1f배: 한 판 %d 프레임(화면 기준), 물리 %d회/초, 시간 배율 %.1f" % [speed, frames, Engine.physics_ticks_per_second, Engine.time_scale])
	return float(frames)


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	for k in 300:
		await physics_frame
	var a := await _round(main, 1.0)
	var b := await _round(main, 2.0)
	var c := await _round(main, 1.5)
	printerr("2배속 / 1배속 시간 비율 = %.2f (0.5 근처면 정상), 1.5배 = %.2f" % [b / a, c / a])
	get_root().get_node("/root/Game").set_game_speed(1.0)
	quit()
