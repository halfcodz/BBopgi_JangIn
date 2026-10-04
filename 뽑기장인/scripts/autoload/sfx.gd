extends Node
## 효과음/배경음 재생기. assets/audio/*.wav

const LOOPS := ["motor_loop", "winch_loop", "bgm_arcade"]
var _streams := {}
var _bgm: AudioStreamPlayer


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	add_child(_bgm)


func stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := "res://assets/audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStreamWAV = load(path)
	if s and name in LOOPS:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_streams[name] = s
	return s


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db + linear_to_db(max(Game.sfx_volume, 0.001))
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_at(name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		play(name, volume_db, pitch)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db + linear_to_db(max(Game.sfx_volume, 0.001))
	p.pitch_scale = pitch
	p.unit_size = 3.0
	p.max_distance = 30.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## 기계 등에 붙여 쓰는 반복 재생기
func make_loop_player(parent: Node3D, name: String, volume_db: float = -8.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	p.unit_size = 2.0
	p.max_distance = 20.0
	parent.add_child(p)
	return p


func play_bgm() -> void:
	_bgm.stream = stream("bgm_arcade")
	_bgm.volume_db = linear_to_db(max(Game.bgm_volume * 0.5, 0.0001))
	_bgm.play()


func set_bgm_volume(v: float) -> void:
	Game.bgm_volume = v
	_bgm.volume_db = linear_to_db(max(v * 0.5, 0.0001))
