extends SceneTree
## 걷는 동안 화면 프레임마다 카메라가 움직인 거리가 고른지(화면 60·50fps와 물리 120틱이 안 맞을 때 덜덜 떨림 확인)
## 실행: godot --headless --fixed-fps 50 -s tests/judder_test.gd

class Probe:
	extends Node
	var cam: Camera3D
	var steps: Array[float] = []
	var last := Vector3.INF
	var on := false
	func _process(_d: float) -> void:
		if not on or cam == null:
			return
		var c := cam.global_position
		if last != Vector3.INF:
			steps.append(Vector2(c.x - last.x, c.z - last.z).length())
		last = c


func _initialize() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	current_scene = main
	var probe := Probe.new()
	probe.process_priority = 10000  # 다른 노드들이 다 움직인 뒤(화면에 그려지기 직전)에 잰다
	get_root().add_child(probe)
	for k in 200:
		await process_frame
	var p = main.player
	probe.cam = p.camera
	p.global_position = Vector3(2.2, 0.05, 2.6)
	p._yaw = PI
	p.rotation.y = PI
	Input.action_press("move_forward")
	for k in 20:
		await process_frame
	probe.on = true
	for k in 30:
		await process_frame
	Input.action_release("move_forward")
	var s := probe.steps
	var mean := 0.0
	for v in s:
		mean += v
	mean /= s.size()
	var dev := 0.0
	for v in s:
		dev += absf(v - mean)
	dev /= s.size()
	printerr("프레임당 카메라 이동 평균 %.4fm, 들쭉날쭉 %.1f%% (작을수록 매끈)" % [mean, dev / mean * 100.0])
	quit()
