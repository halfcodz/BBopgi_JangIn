class_name PrizePool
extends Node3D
## 휴대폰 그리기 최적화: 쉬고 있는(아무도 플레이하지 않고 인형이 다 멈춘) 모든 기계의 인형을
## '같은 모양 + 같은 재질' 끼리 가게 전체에서 하나의 MultiMesh 로 묶어 한 번에 그린다.
## 기계마다 따로 묶으면 기계 수 × 부위 수만큼 그려야 하지만, 가게 전체로 묶으면 부위 종류 수만큼만 그린다.
## 누가 기계를 플레이하기 시작하면 그 기계 인형은 즉시 묶음에서 빠지고 진짜(움직이는) 인형으로 그려진다.

static var instance: PrizePool

var _members := {}   # 기계 → [[메시, 재질, 전역 변환], ...]
var _mmis := {}      # [메시, 재질] → MultiMeshInstance3D
var _dirty := false


func _enter_tree() -> void:
	instance = self
	top_level = true


func _exit_tree() -> void:
	if instance == self:
		instance = null


## 기계의 인형들을 묶음에 넣는다(인형 원래 메시는 숨긴다)
func add_machine(m: Node, prizes_root: Node) -> void:
	var items: Array = []
	for mi in prizes_root.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null or not m3.is_visible_in_tree():
			continue
		items.append([m3.mesh, m3.material_override, m3.global_transform])
		m3.visibility_range_end = 0.01  # 사실상 숨김(묶음이 대신 그림)
	_members[m] = items
	_dirty = true


## 기계를 묶음에서 빼고(같은 프레임에 바로 다시 묶음) 진짜 인형을 다시 그린다
func remove_machine(m: Node, prizes_root: Node) -> void:
	if not _members.has(m):
		return
	_members.erase(m)
	for mi in prizes_root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = 0.0
	rebuild()


func has_machine(m: Node) -> bool:
	return _members.has(m)


func _process(_delta: float) -> void:
	if _dirty:
		rebuild()


func rebuild() -> void:
	_dirty = false
	var groups := {}
	for m in _members:
		for it in _members[m]:
			var key := [it[0], it[1]]
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(it[2])
	# 안 쓰게 된 묶음은 지운다
	for key in _mmis.keys():
		if not groups.has(key):
			(_mmis[key] as Node).queue_free()
			_mmis.erase(key)
	for key in groups:
		var xfs: Array = groups[key]
		var mmi: MultiMeshInstance3D = _mmis.get(key)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = key[0]
			mmi.multimesh = mm
			if key[1]:
				mmi.material_override = key[1]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
			_mmis[key] = mmi
		# 변환 12개 숫자씩 한 번에 채운다(하나씩 넣는 것보다 훨씬 빠름)
		var buf := PackedFloat32Array()
		buf.resize(xfs.size() * 12)
		var o := 0
		for t in xfs:
			var x: Transform3D = t
			buf[o] = x.basis.x.x; buf[o + 1] = x.basis.y.x; buf[o + 2] = x.basis.z.x; buf[o + 3] = x.origin.x
			buf[o + 4] = x.basis.x.y; buf[o + 5] = x.basis.y.y; buf[o + 6] = x.basis.z.y; buf[o + 7] = x.origin.y
			buf[o + 8] = x.basis.x.z; buf[o + 9] = x.basis.y.z; buf[o + 10] = x.basis.z.z; buf[o + 11] = x.origin.z
			o += 12
		var mm2 := mmi.multimesh
		mm2.instance_count = xfs.size()
		mm2.buffer = buf


func draw_groups() -> int:
	return _mmis.size()
