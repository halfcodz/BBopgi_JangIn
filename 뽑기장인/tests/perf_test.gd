extends SceneTree
## 휴대폰 성능 가늠: 가만히 있을 때 / 기계 한 대를 플레이 중일 때 물리 프레임 평균 시간
func _ms(n: int) -> float:
	var t0 := Time.get_ticks_usec()
	for k in n:
		await physics_frame
	return (Time.get_ticks_usec() - t0) / float(n) / 1000.0


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	for k in 600:
		await physics_frame
	printerr("가만히: 물리 프레임당 %.2f ms" % await _ms(240))
	var m = main.shop.machines[0]
	main.player.enter_machine(m)
	m.credits = 1
	m._start_game()
	for k in 30:
		await physics_frame
	m.press_drop()
	var worst := 0.0
	var sum := 0.0
	for k in 600:
		var t0 := Time.get_ticks_usec()
		await physics_frame
		var d := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, d)
		sum += d
	printerr("플레이 중(집게 하강·집기): 평균 %.2f ms, 최악 %.2f ms" % [sum / 600.0, worst])
	quit()
