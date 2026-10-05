extends Node3D
## 게임 시작점: 뽑기방 + 플레이어 + 화면 UI

var shop: Shop
var player: Player
var hud: HUD


## 휴대폰 웹(가로 고정 화면)이면 가게·플레이어·화면 UI 를 처음부터 가로 화면용 SubViewport 안에 만든다
## (다 만든 뒤 옮기면 물리 관절이 끊어져 인형이 흐트러지므로 옮기지 않는다)
func _host() -> Node:
	if Game.landscape_host and Game.landscape_host.vp:
		return Game.landscape_host.vp
	return self


func _ready() -> void:
	var host := _host()
	shop = Shop.new()
	shop.name = "Shop"
	host.add_child(shop)
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(2.2, 0.05, 4.0)
	player.rotation.y = 0.0
	host.add_child(player)
	hud = HUD.new()
	host.add_child(hud)
	hud.bind(player, shop)
	shop.hud = hud
	Sfx.play_bgm()
	# 1분마다 자동 저장
	var t := Timer.new()
	t.wait_time = 60.0
	t.autostart = true
	t.timeout.connect(func(): shop.save_all())
	add_child(t)
	await get_tree().create_timer(0.6).timeout
	Game.say("왼쪽 아래를 밀어 걷고, 오른쪽을 밀어 둘러봐요. 기계를 톡 누르면 플레이!" if Game.touch else "뽑기장인에 오신 걸 환영해요! 기계 앞에서 E, 도움말은 H")


## '처음부터 다시' 등으로 이 장면이 사라질 때, 다른 곳(SubViewport)에 만든 것들도 같이 지운다
func _exit_tree() -> void:
	for n in [shop, player, hud]:
		if n and is_instance_valid(n) and n.get_parent() != self:
			n.queue_free()


var _dbg_t := 0.0


## 웹 시험용: 주소에 ?debug 가 있으면 플레이어 상태를 브라우저(window.__bb)에 적어 둔다
func _process(delta: float) -> void:
	if not OS.has_feature("web") or player == null:
		return
	_dbg_t += delta
	if _dbg_t < 0.25:
		return
	_dbg_t = 0.0
	if not _dbg_on():
		return
	var p := player.global_position
	JavaScriptBridge.eval("window.__bb = {x:%f, z:%f, yaw:%f, mode:%d, speed:%f, fps:%d};" % [p.x, p.z, player._yaw, player.mode, Engine.time_scale, Engine.get_frames_per_second()])


var _dbg := -1


func _dbg_on() -> bool:
	if _dbg < 0:
		_dbg = 1 if bool(JavaScriptBridge.eval("location.search.indexOf('debug') >= 0")) else 0
	return _dbg == 1


func _notification(what: int) -> void:
	# 창 닫기 / 아이폰에서 홈으로 나가기·다른 앱으로 전환할 때 저장(백그라운드 앱은 언제든 종료될 수 있다)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if shop:
			shop.save_all()
		Game.save_game()
