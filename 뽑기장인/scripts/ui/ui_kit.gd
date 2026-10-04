class_name UIKit
extends RefCounted
## 화면 UI 공통 스타일(파스텔 뽑기방 테마)

const PINK := Color(1.0, 0.45, 0.66)
const PINK_DARK := Color(0.55, 0.12, 0.32)
const CREAM := Color(1.0, 0.97, 0.93)
const INK := Color(0.25, 0.14, 0.24)
const MINT := Color(0.45, 0.85, 0.75)
const SKY := Color(0.45, 0.7, 1.0)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var f: FontFile = load("res://assets/fonts/Jua-Regular.ttf")
	t.default_font = f
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(1.0, 0.97, 0.98, 0.96)
	panel.border_color = PINK
	panel.set_border_width_all(4)
	panel.set_corner_radius_all(18)
	panel.set_content_margin_all(16)
	panel.shadow_color = Color(0, 0, 0, 0.25)
	panel.shadow_size = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = PINK
	btn.set_corner_radius_all(12)
	btn.set_content_margin_all(8)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	var btn_h := btn.duplicate()
	btn_h.bg_color = PINK.lightened(0.15)
	var btn_p := btn.duplicate()
	btn_p.bg_color = PINK.darkened(0.2)
	var btn_d := btn.duplicate()
	btn_d.bg_color = Color(0.75, 0.7, 0.74)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("pressed", "Button", btn_p)
	t.set_stylebox("disabled", "Button", btn_d)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_color", "Label", INK)
	for cls in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, UIKit.PINK_DARK)
		t.set_color("font_pressed_color", cls, INK)
		t.set_color("font_hover_pressed_color", cls, UIKit.PINK_DARK)
	t.set_color("font_color", "OptionButton", Color.WHITE)
	t.set_stylebox("normal", "OptionButton", btn)
	t.set_stylebox("hover", "OptionButton", btn_h)
	t.set_stylebox("pressed", "OptionButton", btn_p)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = PINK
	tab_sel.set_corner_radius_all(10)
	tab_sel.set_content_margin_all(8)
	var tab_un := tab_sel.duplicate()
	tab_un.bg_color = Color(1.0, 0.8, 0.88)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_sel)
	var tab_panel := StyleBoxFlat.new()
	tab_panel.bg_color = Color(1, 1, 1, 0.6)
	tab_panel.set_corner_radius_all(12)
	tab_panel.set_content_margin_all(10)
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", INK)
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(1, 1, 1)
	line.border_color = PINK
	line.set_border_width_all(2)
	line.set_corner_radius_all(8)
	line.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("normal", "SpinBox", line)
	t.set_color("font_color", "LineEdit", INK)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(1.0, 0.82, 0.9)
	slider.set_corner_radius_all(6)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	var grab := StyleBoxFlat.new()
	grab.bg_color = PINK
	grab.set_corner_radius_all(6)
	grab.content_margin_top = 4
	grab.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t


static func label(text: String, size := 20, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String, size := 30) -> Label:
	var l := label(text, size, PINK_DARK)
	l.add_theme_font_override("font", load("res://assets/fonts/BlackHanSans-Regular.ttf"))
	return l


static func button(text: String, cb: Callable, color := PINK) -> Button:
	var b := Button.new()
	b.text = text
	if color != PINK:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate()
		sh.bg_color = color.lightened(0.15)
		b.add_theme_stylebox_override("hover", sh)
	b.pressed.connect(func():
		Sfx.play("ui", -8.0)
		cb.call())
	b.focus_mode = Control.FOCUS_NONE
	return b
