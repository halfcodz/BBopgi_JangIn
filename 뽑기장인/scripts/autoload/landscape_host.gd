class_name LandscapeHost
extends Node
## 휴대폰 웹: 게임을 언제나 '가로'로 보여 준다.
## 사파리는 화면 방향을 잠글 수 없으므로, 휴대폰을 세로로 들고 있으면 게임 화면 전체를 90° 돌려 그린다
## (휴대폰을 옆으로 눕혀 들면 똑바로 보임). 휴대폰이 가로면 그대로 그리고, 가로 두 방향 전환은 휴대폰이 알아서 한다.
## 방법: 게임 장면(main)을 가로 크기의 SubViewport 안으로 옮기고, 그 그림을 돌려서 화면에 붙인다.
## 터치 좌표도 SubViewportContainer 가 돌림을 거꾸로 계산해 게임에 넘겨 준다.

const BASE_H := 720.0  # 글씨·버튼 크기 기준(가로 화면 높이 720 단위)

var container: SubViewportContainer
var vp: SubViewport
var layer: CanvasLayer
var _last := Vector2i(-1, -1)
var rotated := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := get_tree().root
	# 화면 크기 맞춤은 여기서 직접 한다(원래 화면 늘리기는 끔)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	layer = CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	container = SubViewportContainer.new()
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(container)
	vp = SubViewport.new()
	vp.handle_input_locally = true
	vp.audio_listener_enable_2d = true
	vp.audio_listener_enable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size_2d_override_stretch = true
	vp.physics_object_picking = false
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = root.scaling_3d_scale
	vp.mesh_lod_threshold = root.mesh_lod_threshold
	container.add_child(vp)
	_layout(true)


func _process(_delta: float) -> void:
	_layout(false)


func _layout(force: bool) -> void:
	var s: Vector2i = get_tree().root.size
	if s == _last and not force:
		return
	_last = s
	if s.x <= 0 or s.y <= 0:
		return
	rotated = s.y > s.x
	var land := Vector2i(maxi(s.x, s.y), mini(s.x, s.y))
	vp.size = land
	vp.size_2d_override = Vector2i(int(round(BASE_H * land.x / float(land.y))), int(BASE_H))
	container.size = Vector2(land)
	if rotated:
		# 시계 방향 90°: 게임의 위쪽이 휴대폰 오른쪽 가장자리로 → 휴대폰을 왼쪽으로 눕히면 똑바로
		container.rotation = PI * 0.5
		container.position = Vector2(s.x, 0)
	else:
		container.rotation = 0.0
		container.position = Vector2.ZERO
