class_name GachaMachine
extends Node3D
## 캡슐뽑기(가챠) 기계 한 칸. 돈을 넣고 손잡이를 돌리면 캡슐이 굴러 나온다.

@export var title := "동물 피규어"
@export var price := 1000
@export var color := Color(0.98, 0.55, 0.3)

var knob: Node3D
var tray_capsule: Prize
var _busy := false
var _rng := RandomNumberGenerator.new()
var spawn_point: Vector3


func _ready() -> void:
	_rng.randomize()
	var body := Build.mat(color, 0.3, 0.1)
	body.clearcoat_enabled = true
	var white := Build.mat(Color(0.96, 0.96, 0.97), 0.3)
	var dark := Build.mat(Color(0.08, 0.08, 0.1), 0.5)
	var W := 0.42
	var D := 0.4
	# 아래 몸통
	Build.box(self, Vector3(W, 0.4, D), Vector3(0, 0.2, 0), body)
	Build.box(self, Vector3(W - 0.04, 0.16, 0.01), Vector3(0, 0.3, D * 0.5 + 0.001), white)
	Build.text(self, title, Vector3(0, 0.33, D * 0.5 + 0.007), 40, 0.0011, color.darkened(0.5), Color.WHITE, "res://assets/fonts/BlackHanSans-Regular.ttf")
	Build.text(self, "1회 %s" % Game.won(price), Vector3(0, 0.27, D * 0.5 + 0.007), 30, 0.0011, Color(0.85, 0.15, 0.3), Color.WHITE)
	# 동전 투입구 + 손잡이
	Build.box(self, Vector3(0.06, 0.1, 0.02), Vector3(0.13, 0.15, D * 0.5 + 0.01), Build.mat(Color(0.8, 0.8, 0.82), 0.2, 1.0))
	Build.box(self, Vector3(0.006, 0.05, 0.022), Vector3(0.13, 0.16, D * 0.5 + 0.012), dark)
	knob = Node3D.new()
	knob.position = Vector3(-0.02, 0.15, D * 0.5 + 0.02)
	add_child(knob)
	Build.cyl(knob, 0.055, 0.03, Vector3.ZERO, Build.mat(Color(0.85, 0.85, 0.88), 0.2, 1.0), Vector3(PI / 2, 0, 0))
	Build.box(knob, Vector3(0.11, 0.022, 0.03), Vector3(0, 0, 0.02), Build.mat(Color(0.95, 0.2, 0.25), 0.3))
	# 배출구(트레이)
	var tray_y := 0.02
	Build.box(self, Vector3(0.13, 0.09, 0.012), Vector3(-0.12, 0.085, D * 0.5 + 0.004), dark, 1)
	Build.box(self, Vector3(0.13, 0.012, 0.09), Vector3(-0.12, tray_y + 0.03, D * 0.5 + 0.035), Build.mat(Color(0.75, 0.75, 0.78), 0.3, 0.8), 1)
	Build.box(self, Vector3(0.13, 0.05, 0.012), Vector3(-0.12, tray_y + 0.055, D * 0.5 + 0.08), Build.glass(Color(0.9, 0.9, 1.0, 0.35)), 1)
	Build.box(self, Vector3(0.012, 0.05, 0.09), Vector3(-0.185, tray_y + 0.055, D * 0.5 + 0.035), Build.mat(Color(0.75, 0.75, 0.78), 0.3, 0.8), 1)
	Build.box(self, Vector3(0.012, 0.05, 0.09), Vector3(-0.055, tray_y + 0.055, D * 0.5 + 0.035), Build.mat(Color(0.75, 0.75, 0.78), 0.3, 0.8), 1)
	Build.box(self, Vector3(0.13, 0.012, 0.09), Vector3(-0.12, tray_y + 0.11, D * 0.5 + 0.03), Build.mat(Color(0.75, 0.75, 0.78), 0.3, 0.8), 1)
	spawn_point = Vector3(-0.12, tray_y + 0.075, D * 0.5 + 0.03)
	# 위쪽 투명 캡슐 창
	Build.box(self, Vector3(W, 0.02, D), Vector3(0, 0.41, 0), white)
	Build.box(self, Vector3(W, 0.4, D), Vector3(0, 0.62, 0), Build.glass(Color(0.9, 0.95, 1.0, 0.12)))
	Build.box(self, Vector3(W, 0.03, D), Vector3(0, 0.835, 0), body)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Build.box(self, Vector3(0.02, 0.4, 0.02), Vector3(sx * (W * 0.5 - 0.01), 0.62, sz * (D * 0.5 - 0.01)), white)
	# 안에 쌓인 캡슐들(정적 장식)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.032
	sm.height = 0.064
	sm.radial_segments = 16
	sm.rings = 8
	mm.mesh = sm
	var n := 46
	mm.instance_count = n
	var cols := [Color(0.95, 0.35, 0.42), Color(0.3, 0.62, 0.96), Color(0.98, 0.84, 0.28), Color(0.52, 0.84, 0.5), Color(0.72, 0.52, 0.95), Color(1, 1, 1)]
	for i in n:
		var layer := i / 16
		var k := i % 16
		var x := -0.16 + (k % 4) * 0.105 + _rng.randf_range(-0.01, 0.01) + (0.05 if layer % 2 == 1 else 0.0)
		var z := -0.15 + (k / 4) * 0.1 + _rng.randf_range(-0.01, 0.01)
		var y := 0.455 + layer * 0.058 + _rng.randf_range(0, 0.008)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(), _rng.randf() * TAU), Vector3(clamp(x, -0.17, 0.17), y, z)))
		mm.set_instance_color(i, cols[_rng.randi() % cols.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.15
	cm.metallic_specular = 0.8
	mmi.material_override = cm
	add_child(mmi)
	Build.interact_body(self, self, Vector3(W + 0.02, 0.86, D + 0.1), Vector3(0, 0.43, 0.05))
	if Game.touch:
		# 휴대폰: 움직이지 않는 부품을 재질별로 합쳐 그리기 횟수를 줄인다(버튼처럼 바뀌는 부품은 그대로)
		RenderBatcher.merge_static.call_deferred(self, RenderBatcher.referenced_nodes(self), RenderBatcher.referenced_materials(self))


func interact_prompt() -> String:
	if tray_capsule and is_instance_valid(tray_capsule):
		return "[E] 캡슐 꺼내기"
	return "[E] %s 캡슐뽑기 (%s)" % [title, Game.won(price)]


func interact(_player) -> void:
	if _busy:
		return
	if tray_capsule and is_instance_valid(tray_capsule):
		Game.add_to_collection("capsule", tray_capsule.colorway, "gacha")
		Game.say("캡슐 속에서 '%s'가 나왔어요!" % _random_toy())
		tray_capsule.queue_free()
		tray_capsule = null
		Sfx.play("credit", -4.0)
		return
	# 결제: 500원 동전 우선, 없으면 1,000원 지폐
	var coins_needed := price / 500
	if int(Game.wallet.get("500", 0)) >= coins_needed:
		for i in coins_needed:
			Game.take_bill("500")
		Sfx.play_at("coin", global_position + Vector3(0.13, 0.15, 0.25))
	elif price % 1000 == 0 and int(Game.wallet.get("1000", 0)) >= price / 1000:
		for i in price / 1000:
			Game.take_bill("1000")
		Sfx.play_at("bill_insert", global_position + Vector3(0.13, 0.15, 0.25), -6.0)
	else:
		Game.say("돈이 모자라요 (%s 필요)" % Game.won(price))
		return
	Game.record_spend(price)
	Game.stats["gacha"] = int(Game.stats.get("gacha", 0)) + 1
	_busy = true
	Game.keep_active(4000)  # 손잡이 돌리고 캡슐 떨어지는 동안 60fps
	Sfx.play_at("gacha_crank", global_position + Vector3(0, 0.15, 0.25))
	var tw := create_tween()
	tw.tween_property(knob, "rotation:z", knob.rotation.z - TAU, 1.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var cap := PrizeFactory.create("capsule", _rng)
	get_tree().current_scene.add_child(cap)
	cap.global_transform = global_transform * Transform3D(Basis(), spawn_point + Vector3(0, 0.0, -0.01))
	for b in cap.bodies:
		b.apply_central_impulse(global_transform.basis * Vector3(0, 0, 0.02) * b.mass * 10.0)
	tray_capsule = cap
	Sfx.play_at("capsule_drop", global_position + Vector3(-0.12, 0.1, 0.25))
	_busy = false


func _random_toy() -> String:
	var toys := ["미니 고양이 피규어", "아기 공룡 피규어", "말랑 곰 지비츠", "펭귄 키링", "토끼 미니 피규어", "반짝 스티커", "오리 미니 인형", "시크릿 레어 피규어"]
	return toys[_rng.randi() % toys.size()]
