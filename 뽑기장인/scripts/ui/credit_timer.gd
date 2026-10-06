class_name CreditTimer
extends Control
## 기계 앞에서 화면 위 가운데에 크게 보이는 CREDIT · TIME 전광판.
## 왼쪽 = 남은 크레딧(넣을 때마다 통통 튐), 오른쪽 = 남은 시간(숫자 + 줄어드는 막대, 5초 이하면 빨갛게 깜빡).

const W := 380.0
const H := 96.0
const SPLIT := 148.0

const BG := Color(0.15, 0.07, 0.21, 0.88)
const EDGE := Color(1.0, 0.5, 0.8)
const CAPTION := Color(1.0, 0.74, 0.9)
const DIM := Color(1, 1, 1, 0.35)
const MINT := Color(0.45, 0.95, 0.78)
const YELLOW := Color(1.0, 0.84, 0.35)
const RED := Color(1.0, 0.33, 0.42)

var machine: ClawMachine
var _font: Font
var _style := StyleBoxFlat.new()
var _t := 0.0
var _last_credits := -1
var _pop := 0.0       # 크레딧이 바뀌면 1 → 0 으로 줄며 숫자가 커졌다 돌아옴


func _ready() -> void:
	_font = load("res://assets/fonts/Jua-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	_style.bg_color = BG
	_style.set_corner_radius_all(26)
	_style.set_border_width_all(3)
	_style.border_color = EDGE
	_style.shadow_color = Color(0, 0, 0, 0.28)
	_style.shadow_size = 10
	_style.shadow_offset = Vector2(0, 4)


func _process(delta: float) -> void:
	if not visible or machine == null:
		return
	_t += delta / maxf(Engine.time_scale, 0.01)
	if machine.credits != _last_credits:
		if _last_credits >= 0 and machine.credits > _last_credits:
			_pop = 1.0
		_last_credits = machine.credits
	_pop = maxf(0.0, _pop - delta * 3.0)
	queue_redraw()


func _moving() -> bool:
	return machine.state == ClawMachine.State.MOVING


func _draw() -> void:
	if machine == null:
		return
	var low := _moving() and machine.time_left <= 5.0
	var flash := low and fmod(machine.time_left, 1.0) > 0.5
	_style.border_color = RED if flash else EDGE
	draw_style_box(_style, Rect2(Vector2.ZERO, Vector2(W, H)))
	# 가운데 칸막이
	draw_line(Vector2(SPLIT, 16), Vector2(SPLIT, H - 16), Color(1, 1, 1, 0.16), 2.0)

	# ---- 왼쪽: CREDIT
	_text_center("CREDIT", Vector2(SPLIT * 0.5, 26), 16, CAPTION)
	var c := machine.credits
	var size_c := int(46 + 14 * _pop)
	_text_center(str(c), Vector2(SPLIT * 0.5, 74 + 4 * _pop), size_c, Color.WHITE if c > 0 else DIM)

	# ---- 오른쪽: TIME
	var rx := SPLIT + (W - SPLIT) * 0.5
	_text_center("TIME", Vector2(rx, 26), 16, CAPTION)
	var bar := Rect2(SPLIT + 26, H - 22, W - SPLIT - 52, 9)
	if _moving():
		var total := maxf(float(machine.settings.get("timer_sec", 30)), 1.0)
		var frac := clampf(machine.time_left / total, 0.0, 1.0)
		var col := MINT if frac > 0.5 else (YELLOW if frac > 0.25 else RED)
		if low:
			col = RED
		var sec := int(ceil(machine.time_left))
		var bump := 0.0
		if low:
			# 초가 바뀌는 순간 숫자가 살짝 커졌다 돌아온다(남은 시간 = 소수 부분이 1 → 0 으로 줄어듦)
			var f := machine.time_left - floorf(machine.time_left)
			bump = clampf((f - 0.75) * 4.0, 0.0, 1.0)
		var fs := int(44 + 10 * bump)
		var num := "%d" % sec
		var wn := _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ws := _font.get_string_size("초", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var x0 := rx - (wn + 4 + ws) * 0.5
		_text_left(num, Vector2(x0, 68), fs, col)
		_text_left("초", Vector2(x0 + wn + 4, 68), 20, col)
		_bar(bar, frac, col)
	elif machine.state == ClawMachine.State.IDLE:
		if c > 0:
			# 크레딧은 있고 아직 시작 전: READY 가 숨 쉬듯 반짝
			var a := 0.65 + 0.35 * sin(_t * 4.0)
			_text_center("READY", Vector2(rx, 66), 34, Color(1.0, 0.62, 0.86, a))
			_bar(bar, 1.0, Color(MINT, 0.5 + 0.3 * sin(_t * 4.0)))
		else:
			_text_center("--", Vector2(rx, 68), 40, DIM)
			_bar(bar, 0.0, MINT)
	else:
		# 집게가 내려가고 집는 중
		var dots := ".".repeat(1 + int(_t * 3.0) % 3)
		_text_center("집는 중" + dots, Vector2(rx, 64), 26, Color.WHITE)
		_bar(bar, 0.0, MINT)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(bg, r)
	if frac > 0.0:
		var fg := StyleBoxFlat.new()
		fg.bg_color = col
		fg.set_corner_radius_all(int(r.size.y * 0.5))
		draw_style_box(fg, Rect2(r.position, Vector2(maxf(r.size.y, r.size.x * frac), r.size.y)))


func _text_center(t: String, baseline_center: Vector2, fs: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(baseline_center.x - w * 0.5, baseline_center.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _text_left(t: String, baseline_left: Vector2, fs: int, col: Color) -> void:
	draw_string(_font, baseline_left, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
