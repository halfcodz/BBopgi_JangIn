class_name OwnerCounter
extends Node3D
## 사장님 카운터: 계산대, 입고 박스, CCTV 모니터. E 로 사장 모드를 연다.

var monitor_label: Label3D
var _t := 0.0


func _ready() -> void:
	var wood := Build.mat(Color(0.55, 0.38, 0.26), 0.55)
	var top := Build.mat(Color(0.95, 0.94, 0.92), 0.25)
	var pink := Build.mat(Color(1.0, 0.45, 0.66), 0.4)
	Build.box(self, Vector3(1.8, 1.0, 0.6), Vector3(0, 0.5, 0), wood)
	Build.box(self, Vector3(1.9, 0.05, 0.7), Vector3(0, 1.02, 0), top)
	Build.box(self, Vector3(1.8, 0.12, 0.01), Vector3(0, 0.8, -0.305), pink)
	Build.text(self, "사장님 카운터", Vector3(0, 0.62, -0.31), 60, 0.0012, Color(1, 1, 1)).rotation.y = PI
	Build.blocker(self, Vector3(1.9, 1.1, 0.7), Vector3(0, 0.55, 0))
	# 모니터(CCTV/매출)
	var mon := Node3D.new()
	mon.position = Vector3(-0.45, 1.05, 0.05)
	mon.rotation.y = PI
	add_child(mon)
	Build.box(mon, Vector3(0.5, 0.32, 0.03), Vector3(0, 0.3, 0), Build.mat(Color(0.08, 0.08, 0.1), 0.4))
	Build.box(mon, Vector3(0.46, 0.28, 0.005), Vector3(0, 0.3, 0.017), Build.glow(Color(0.1, 0.18, 0.3), 0.8))
	Build.box(mon, Vector3(0.05, 0.14, 0.05), Vector3(0, 0.07, 0), Build.mat(Color(0.2, 0.2, 0.22), 0.4))
	monitor_label = Build.text(mon, "", Vector3(0, 0.3, 0.022), 22, 0.0011, Color(0.6, 1.0, 0.7), Color(0, 0, 0, 0), "res://assets/fonts/DoHyeon-Regular.ttf")
	monitor_label.outline_size = 0
	monitor_label.shaded = false
	# 계산기/돈통
	Build.box(self, Vector3(0.3, 0.12, 0.25), Vector3(0.35, 1.1, 0.0), Build.mat(Color(0.2, 0.2, 0.24), 0.4))
	Build.box(self, Vector3(0.26, 0.02, 0.2), Vector3(0.35, 1.17, 0.0), Build.mat(Color(0.75, 0.75, 0.78), 0.3, 0.6))
	Build.decor(self, "plantSmall1", Vector3(0.75, 1.045, 0.1), 1.6)
	# 입고 박스
	Build.decor(self, "cardboardBoxOpen", Vector3(1.3, 0, 0.2), 1.6, 0.3)
	Build.decor(self, "cardboardBoxOpen", Vector3(1.25, 0.45, 0.25), 1.4, -0.4)
	var tag := Build.text(self, "신상 인형 입고", Vector3(1.3, 0.62, -0.18), 28, 0.0012, Color(1, 1, 1))
	tag.rotation.y = PI
	Build.interact_body(self, self, Vector3(1.9, 1.3, 0.9), Vector3(0, 0.65, 0))


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		return
	_t = 0.0
	var rev := 0
	for k in Game.ledgers:
		rev += int(Game.ledgers[k].get("revenue", 0))
	monitor_label.text = "오늘 매출\n%s\n%s" % [Game.won(rev), Time.get_time_string_from_system().substr(0, 5)]


func interact_prompt() -> String:
	return "[E] 사장 모드 열기 (기계 세팅·상품 진열·매출 장부)"


func interact(player) -> void:
	var hud = get_tree().current_scene.get("hud")
	if hud:
		hud._toggle_owner()
