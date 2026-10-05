class_name BridgeGuide
extends PanelContainer
## 일본식 다리(橋渡し) 기계 공략 도우미: 위에서 내려다본 작은 그림(봉·상자·집게)과
## 지금 상자 상태에 맞는 '다음에 할 일' 한 줄을 보여 준다. 노린 곳은 반짝이는 원으로 표시.

var machine: BridgeMachine
var step_label: Label
var tip_label: Label
var view: Control
var _t := 0.0
var _target := Vector2.ZERO  # 노릴 곳(기계 로컬 x,z)
var _step := 1

const MAP_W := 250.0
const MAP_H := 210.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	v.add_child(UIKit.title("공략 도우미 (위에서 본 모습)", 17))
	view = Control.new()
	view.custom_minimum_size = Vector2(MAP_W, MAP_H)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_map)
	v.add_child(view)
	step_label = UIKit.title("", 19)
	v.add_child(step_label)
	tip_label = UIKit.label("", 15)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.custom_minimum_size = Vector2(MAP_W, 0)
	v.add_child(tip_label)


func _process(delta: float) -> void:
	if not visible or machine == null:
		return
	_t += delta
	_analyse()
	view.queue_redraw()


func _box() -> RigidBody3D:
	for p in machine.get_prizes():
		if not p.won and not p.bodies.is_empty():
			return p.bodies[0]
	return null


## 상자 상태 → 단계·노릴 곳·설명
func _analyse() -> void:
	var b := _box()
	if b == null:
		_step = 0
		step_label.text = "상자를 기다리는 중"
		tip_label.text = "사장 모드에서 상자를 채울 수 있어요."
		return
	var lb: Basis = machine.global_transform.basis.inverse() * b.global_transform.basis
	var c: Vector3 = machine.to_local(b.global_position)
	var ax: Vector3 = lb.x  # 상자 긴 변
	var e1: Vector3 = c + ax * 0.13
	var e2: Vector3 = c - ax * 0.13
	var hi: Vector3 = e1 if e1.y > e2.y else e2
	var stand := rad_to_deg(asin(clampf(absf(ax.y), 0.0, 1.0)))  # 0 = 누움, 90 = 똑바로 섬
	var bar := machine._gap() * 0.5
	if stand > 60.0:
		_step = 3
		_target = Vector2(hi.x, hi.z)
		step_label.text = "③ 거의 섰어요!"
		tip_label.text = "위로 올라온 끝을 살짝 건드리면 똑바로 서면서 쏙 빠져요."
	elif stand > 12.0:
		_step = 2
		_target = Vector2(hi.x, hi.z)
		step_label.text = "② 비스듬히 걸렸어요"
		tip_label.text = "들린 쪽 끝(반짝이는 곳)을 집어 살짝 들어 주면 상자가 점점 섭니다. 기울어진 채로는 안 빠져요."
	elif absf(c.z) > bar:
		_step = 1
		var e_out: Vector3 = e1 if absf(e1.z) > absf(e2.z) else e2
		_target = Vector2(e_out.x, e_out.z)
		step_label.text = "① 너무 밀렸어요"
		tip_label.text = "받침대 쪽으로 나간 끝을 살짝 들어서 봉 사이 쪽으로 되돌리세요."
	else:
		_step = 1
		# 이미 치우친 방향으로 계속 민다: 반대쪽 끝을 들면 상자가 그쪽으로 밀린다
		var dir := -signf(c.z) if absf(c.z) > 0.01 else 1.0
		var e_push: Vector3 = e1 if signf(e1.z - c.z) == dir else e2
		_target = Vector2(e_push.x, e_push.z)
		step_label.text = "① 끝을 살짝 들어 밀기"
		tip_label.text = "무거워서 통째로는 안 들려요. 반짝이는 끝을 노려 조금씩 밀면, 반대쪽 끝이 봉 사이로 떨어지며 기울어요."


func _to_map(x: float, z: float) -> Vector2:
	var u := inverse_lerp(-machine.ix, machine.ix, x)
	var v := inverse_lerp(machine.z_back, machine.z_front, z)
	return Vector2(10.0 + u * (MAP_W - 20.0), 8.0 + v * (MAP_H - 16.0))


func _draw_map() -> void:
	if machine == null:
		return
	var a := _to_map(-machine.ix, machine.z_back)
	var bb := _to_map(machine.ix, machine.z_front)
	view.draw_rect(Rect2(a, bb - a), Color(0.93, 0.95, 0.98))
	view.draw_rect(Rect2(a, bb - a), Color(0.6, 0.62, 0.7), false, 2.0)
	view.draw_string(get_theme_default_font(), Vector2(a.x + 4, bb.y - 4), "앞(나)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 0.45, 0.55))
	# 봉
	for line in machine._bar_lines():
		var p0: Vector3 = line[0]
		var p1: Vector3 = line[1]
		view.draw_line(_to_map(p0.x, p0.z), _to_map(p1.x, p1.z), Color(0.35, 0.36, 0.42), 5.0)
	# 상자(바닥에 비친 모양)
	var b := _box()
	if b:
		var lb: Basis = machine.global_transform.basis.inverse() * b.global_transform.basis
		var c: Vector3 = machine.to_local(b.global_position)
		var half := Vector3(0.14, 0.10, 0.075)
		var pts := PackedVector2Array()
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var q: Vector3 = c + lb.x * half.x * sx + lb.y * half.y * sy + lb.z * half.z * sz
					pts.append(_to_map(q.x, q.z))
		var hull := Geometry2D.convex_hull(pts)
		if hull.size() >= 3:
			view.draw_colored_polygon(hull, Color(1.0, 0.55, 0.72, 0.85))
			view.draw_polyline(hull, Color(0.7, 0.2, 0.4), 2.0)
	# 노릴 곳(반짝임)
	if _step > 0:
		var tp := _to_map(_target.x, _target.y)
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		view.draw_circle(tp, 9.0 + pulse * 5.0, Color(1.0, 0.85, 0.1, 0.35 + pulse * 0.3))
		view.draw_arc(tp, 13.0, 0.0, TAU, 24, Color(1.0, 0.75, 0.0), 2.0)
	# 집게(지금 위치 + 팔 벌어지는 폭)
	var cp := _to_map(machine.carriage.x, machine.carriage.z)
	var arm := _to_map(machine.carriage.x + 0.15, machine.carriage.z)
	view.draw_line(Vector2(cp.x - (arm.x - cp.x), cp.y), arm, Color(0.25, 0.5, 1.0, 0.8), 2.0)
	view.draw_circle(cp, 6.0, Color(0.2, 0.45, 1.0))
	view.draw_circle(cp, 2.5, Color(1, 1, 1))
