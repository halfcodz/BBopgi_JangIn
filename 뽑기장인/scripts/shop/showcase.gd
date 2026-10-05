class_name Showcase
extends Node3D
## 나의 전시장: 뽑은 인형·상품을 유리 진열장에 실제 모습 그대로 진열한다.

## 진열장 배치: [로컬 위치, y 회전(라디안), 종류("big"/"small")]
var cabinets := []
var slots_big: Array[Transform3D] = []
var slots_small: Array[Transform3D] = []
var display_root: Node3D
var board: Label3D
var overflow_label: Label3D
var _dirty := true


func setup(cabinet_list: Array) -> void:
	cabinets = cabinet_list


func _ready() -> void:
	display_root = Node3D.new()
	add_child(display_root)
	for c in cabinets:
		_build_cabinet(c[0], c[1], c[2])
	Game.collection_changed.connect(func(): _dirty = true)


func _build_cabinet(pos: Vector3, rot_y: float, kind: String) -> void:
	var cab := Node3D.new()
	cab.position = pos
	cab.rotation.y = rot_y
	add_child(cab)
	var W := 1.2
	var D := 0.44
	var H := 2.05
	var frame := Build.mat(Color(0.97, 0.96, 0.95), 0.35)
	var wood := Build.mat(Color(0.45, 0.3, 0.2), 0.6)
	var back := Build.mat(Color(1.0, 0.86, 0.9), 0.8)
	# 받침·윗판·뒷판은 양옆 판 사이에 끼운다(같은 면이 겹쳐 아래쪽이 깜빡이던 문제)
	Build.box(cab, Vector3(W - 0.06, 0.18, D - 0.004), Vector3(0, 0.09, 0.0), wood)
	Build.box(cab, Vector3(W - 0.06, 0.06, D - 0.004), Vector3(0, H - 0.03, 0), frame)
	Build.box(cab, Vector3(W - 0.06, H - 0.24, 0.02), Vector3(0, 0.18 + (H - 0.24) * 0.5, -D * 0.5 + 0.012), back)
	for sx in [-1.0, 1.0]:
		Build.box(cab, Vector3(0.03, H, D), Vector3(sx * (W * 0.5 - 0.015), H * 0.5, 0), frame)
	Build.box(cab, Vector3(W - 0.06, H - 0.24, 0.006), Vector3(0, 0.18 + (H - 0.24) * 0.5, D * 0.5 - 0.004), Build.glass())
	Build.blocker(cab, Vector3(W, H, D), Vector3(0, H * 0.5, 0))
	var shelf_glass := Build.glass(Color(0.9, 0.97, 1.0, 0.25))
	var led := Build.glow(Color(1.0, 0.97, 0.9), 3.0)
	var rows := [0.18, 0.62, 1.06, 1.5] if kind == "big" else [0.18, 0.5, 0.82, 1.14, 1.46, 1.74]
	for i in rows.size():
		var y: float = rows[i]
		if i > 0:
			Build.box(cab, Vector3(W - 0.06, 0.012, D - 0.04), Vector3(0, y, 0), shelf_glass)
		Build.box(cab, Vector3(W - 0.08, 0.008, 0.012), Vector3(0, (rows[i + 1] if i + 1 < rows.size() else H - 0.06) - 0.012, D * 0.5 - 0.04), led)
		var n := 3 if kind == "big" else 6
		for k in n:
			var x := -W * 0.5 + 0.03 + (k + 0.5) * (W - 0.06) / n
			var xf := Transform3D(Basis(), Vector3(x, y + 0.012, 0.0))
			if kind == "big":
				slots_big.append(cab.transform * xf)
			else:
				slots_small.append(cab.transform * xf)
	var light := SpotLight3D.new()
	light.position = Vector3(0, H + 0.4, 0.9)
	light.rotation = Vector3(-1.05, 0, 0)
	light.spot_angle = 38
	light.spot_range = 3.5
	light.light_energy = 1.4
	light.light_color = Color(1.0, 0.95, 0.88)
	cab.add_child(light)
	Build.text(cab, "큰 인형 진열장" if kind == "big" else "작은 상품 진열장", Vector3(0, H + 0.08, D * 0.5), 34, 0.0012, Color(1, 1, 1))


func build_board(pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	Build.box(n, Vector3(1.3, 0.9, 0.04), Vector3(0, 0, 0), Build.mat(Color(0.25, 0.16, 0.24), 0.6))
	Build.box(n, Vector3(1.36, 0.96, 0.03), Vector3(0, 0, -0.01), Build.mat(Color(1.0, 0.75, 0.3), 0.3, 0.6))
	board = Build.text(n, "", Vector3(0, 0, 0.025), 40, 0.0012, Color(1, 1, 1), Color(0, 0, 0, 0))
	board.outline_size = 0
	board.width = 1000
	board.autowrap_mode = TextServer.AUTOWRAP_WORD
	var neon := Build.text(n, "나의 전시장", Vector3(0, 0.75, 0.02), 110, 0.0016, Color(1.0, 0.75, 0.9), Color(1.0, 0.3, 0.6), "res://assets/fonts/BlackHanSans-Regular.ttf")
	neon.outline_size = 26
	neon.shaded = false
	overflow_label = Build.text(n, "", Vector3(0, -0.6, 0.02), 30, 0.0012, Color(1, 1, 1))


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		refresh()


func refresh() -> void:
	for c in display_root.get_children():
		c.queue_free()
	var bi := 0
	var si := 0
	var hidden := 0
	# 최근에 뽑은 것부터 진열
	var order: Array = range(Game.collection.size())
	order.reverse()
	for ci in order:
		var e: Dictionary = Game.collection[ci]
		var id: String = e["id"]
		var item := PrizeCatalog.get_item(id)
		if item.is_empty():
			continue
		var big: bool = item["size_class"] != "small"
		var slot: Transform3D
		if big:
			if bi >= slots_big.size():
				hidden += 1
				continue
			slot = slots_big[bi]
			bi += 1
		else:
			if si >= slots_small.size():
				hidden += 1
				continue
			slot = slots_small[si]
			si += 1
		var holder := ShowcaseSlot.new()
		holder.entry_index = ci
		holder.prize_name = item["name"]
		holder.transform = slot
		display_root.add_child(holder)
		var ib := Build.interact_body(holder, holder, Vector3(0.34, 0.36, 0.3) if big else Vector3(0.18, 0.24, 0.24), Vector3(0, 0.17 if big else 0.11, 0))
		ib.name = "Pick"
		var p := PrizeFactory.create(id, null, int(e.get("colorway", 0)))
		if p == null:
			continue
		for b in p.bodies:
			b.freeze = true
			b.collision_layer = 0
			b.collision_mask = 0
		display_root.add_child(p)
		p.transform = slot
		var tag := Build.text(display_root, "%s\n%s" % [item["name"], ("%s에 획득" % Game.won(int(e.get("spent", 0)))) if int(e.get("spent", 0)) > 0 else "획득!"], slot.origin + Vector3(0, 0.03, 0.17), 18, 0.0011, Color(0.35, 0.12, 0.25), Color(1, 1, 1))
		tag.transform.basis = slot.basis
		tag.position = slot * Vector3(0, 0.025, 0.17)
	if board:
		var n := Game.collection.size()
		var spent := int(Game.stats["spent"])
		board.text = "획득한 상품  %d개\n도전 횟수  %d판\n쓴 돈  %s\n1개당 평균  %s" % [
			n, int(Game.stats["plays"]), Game.won(spent), Game.won(spent / n if n > 0 else 0)]
		overflow_label.text = ("진열장이 꽉 찼어요! 보관 중 %d개" % hidden) if hidden > 0 else ""
