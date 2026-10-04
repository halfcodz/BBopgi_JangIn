class_name BillChanger
extends Node3D
## 지폐교환기: 10,000원/5,000원권을 넣으면 1,000원권으로 바꿔 준다.

var lcd: Label3D
var _busy := false
var led: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	var body := Build.mat(Color(0.85, 0.87, 0.9), 0.3, 0.6)
	var face := Build.mat(Color(0.18, 0.45, 0.85), 0.35, 0.2)
	var dark := Build.mat(Color(0.06, 0.06, 0.08), 0.4)
	Build.box(self, Vector3(0.56, 1.62, 0.46), Vector3(0, 0.81, 0), body)
	Build.box(self, Vector3(0.5, 1.2, 0.01), Vector3(0, 0.95, 0.235), face)
	Build.box(self, Vector3(0.56, 0.22, 0.48), Vector3(0, 1.73, 0), Build.glow(Color(1.0, 0.85, 0.3), 1.2))
	Build.text(self, "지폐교환기", Vector3(0, 1.73, 0.245), 80, 0.0013, Color(0.35, 0.12, 0.05), Color(1, 1, 1), "res://assets/fonts/BlackHanSans-Regular.ttf")
	# LCD
	Build.box(self, Vector3(0.36, 0.14, 0.012), Vector3(0, 1.36, 0.24), dark)
	lcd = Build.text(self, "", Vector3(0, 1.36, 0.248), 30, 0.0011, Color(0.4, 1.0, 0.5), Color(0, 0, 0, 0), "res://assets/fonts/DoHyeon-Regular.ttf")
	lcd.outline_size = 0
	lcd.shaded = false
	# 투입구
	Build.box(self, Vector3(0.26, 0.12, 0.03), Vector3(0, 1.12, 0.25), Build.mat(Color(0.15, 0.15, 0.17), 0.3, 0.5))
	Build.box(self, Vector3(0.2, 0.008, 0.032), Vector3(0, 1.13, 0.252), Build.mat(Color(0, 0, 0), 1.0))
	led = Build.glow(Color(0.2, 1.0, 0.35), 2.0)
	Build.box(self, Vector3(0.2, 0.005, 0.034), Vector3(0, 1.12, 0.252), led)
	Build.text(self, "10,000원 · 5,000원 → 1,000원", Vector3(0, 1.22, 0.243), 26, 0.0011, Color.WHITE)
	# 배출구
	Build.box(self, Vector3(0.3, 0.12, 0.08), Vector3(0, 0.62, 0.25), dark)
	Build.text(self, "교환된 지폐 나오는 곳", Vector3(0, 0.72, 0.243), 20, 0.0011, Color.WHITE)
	Build.text(self, "※ 동전은 교환되지 않습니다", Vector3(0, 0.4, 0.243), 20, 0.0011, Color(1, 0.95, 0.6))
	Build.interact_body(self, self, Vector3(0.6, 1.8, 0.6), Vector3(0, 0.9, 0))
	Build.blocker(self, Vector3(0.6, 1.9, 0.5), Vector3(0, 0.95, 0))
	_update_lcd()


func _process(delta: float) -> void:
	_t += delta
	led.emission_energy_multiplier = 2.2 if int(_t * 2.0) % 2 == 0 else 0.5


func _update_lcd() -> void:
	lcd.text = "지폐를 넣어 주세요" if not _busy else "교환 중..."


func interact_prompt() -> String:
	if Game.has_bill("10000"):
		return "[E] 10,000원권 교환하기 → 1,000원 x10"
	if Game.has_bill("5000"):
		return "[E] 5,000원권 교환하기 → 1,000원 x5"
	return "지폐교환기 (바꿀 큰 지폐가 없어요)"


func interact(_player) -> void:
	if _busy:
		return
	var kind := ""
	if Game.has_bill("10000"):
		kind = "10000"
	elif Game.has_bill("5000"):
		kind = "5000"
	if kind == "":
		Game.say("교환할 10,000원·5,000원권이 없어요")
		return
	_busy = true
	_update_lcd()
	Game.take_bill(kind)
	Sfx.play_at("changer", global_position + Vector3(0, 1.0, 0.3))
	await get_tree().create_timer(1.4).timeout
	Game.give_money("1000", int(kind) / 1000)
	Game.say("1,000원권 %d장으로 바꿨어요" % (int(kind) / 1000))
	_busy = false
	_update_lcd()
