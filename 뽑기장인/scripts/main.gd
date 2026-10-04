extends Node3D
## 게임 시작점: 뽑기방 + 플레이어 + 화면 UI

var shop: Shop
var player: Player
var hud: HUD


func _ready() -> void:
	shop = Shop.new()
	shop.name = "Shop"
	add_child(shop)
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(2.2, 0.05, 3.3)
	player.rotation.y = 0.0
	add_child(player)
	hud = HUD.new()
	add_child(hud)
	hud.bind(player, shop)
	shop.hud = hud
	Sfx.play_bgm()
	await get_tree().create_timer(0.6).timeout
	Game.say("뽑기장인에 오신 걸 환영해요! 기계 앞에서 E, 도움말은 H")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if shop:
			shop.save_all()
		Game.save_game()
