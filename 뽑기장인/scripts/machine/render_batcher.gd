class_name RenderBatcher
extends RefCounted
## 휴대폰용 그리기 호출 줄이기.
## 1) merge_static: 움직이지 않는 상자·원기둥 같은 부품을 재질별로 한 덩어리 메시로 합친다(기계·가게 벽).
## 2) bake_far: 기계 안 인형들을 재질별로 한 덩어리로 구워, 멀리서는 그 덩어리 하나만 그린다(가까이 오면 진짜 인형).
## 합치는 대상은 '스크립트가 이름으로 붙잡고 있지 않은' 노드만이라 움직이는 부품(집게·조이스틱·버튼·전구)은 그대로다.

const _PRIMS := ["BoxMesh", "CylinderMesh", "QuadMesh", "PlaneMesh", "SphereMesh", "CapsuleMesh", "TorusMesh", "PrismMesh"]


## 스크립트 변수(노드 / 노드 배열 / 사전 값)로 붙잡혀 있는 노드들
static func referenced_nodes(obj: Object) -> Dictionary:
	var out := {}
	for prop in obj.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v = obj.get(prop["name"])
		if v is Node:
			out[v] = true
		elif v is Array:
			for e in v:
				if e is Node:
					out[e] = true
		elif v is Dictionary:
			for e in v.values():
				if e is Node:
					out[e] = true
	return out


static func _opaque_ok(m: Material) -> bool:
	if m == null:
		return true
	if not (m is BaseMaterial3D):
		return false  # 셰이더 재질은 어떤 효과를 쓰는지 몰라 건드리지 않는다
	var b := m as BaseMaterial3D
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return false
	if b.next_pass != null:
		return false
	return true


static func _surface_mat(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var o := mi.get_surface_override_material(s)
	if o:
		return o
	return mi.mesh.surface_get_material(s)


static func _fmt_key(mesh: Mesh, s: int) -> int:
	var arr := mesh.surface_get_arrays(s)
	var k := 1 if arr[Mesh.ARRAY_INDEX] != null else 0
	for a in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_BONES]:
		if arr[a] != null:
			k |= 2 << a
	return k


## root 아래(스크립트가 붙은 다른 노드 안쪽은 제외) 움직이지 않는 기본 도형 메시를 합친다. 합친 개수 반환
static func merge_static(root: Node3D, keep: Dictionary = {}) -> int:
	var cands: Array[MeshInstance3D] = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if keep.has(c):
				continue
			if c.get_script() != null:
				continue  # 다른 장치(집게·자판기·상품 등)는 손대지 않는다
			if not (c is Node3D) or (c as Node3D).top_level:
				continue
			stack.append(c)
			if c is MeshInstance3D and c.get_child_count() == 0 and c.mesh and _PRIMS.has(c.mesh.get_class()):
				var mi: MeshInstance3D = c
				if not mi.is_visible_in_tree():
					continue
				var ok := true
				for s in mi.mesh.get_surface_count():
					if not _opaque_ok(_surface_mat(mi, s)):
						ok = false
				if ok:
					cands.append(mi)
	if cands.size() < 2:
		return 0
	var inv := root.global_transform.affine_inverse()
	var groups := {}  # [재질, 형식, 그림자] → SurfaceTool
	var mats := {}
	for mi in cands:
		var xf := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var m := _surface_mat(mi, s)
			var key := [m, _fmt_key(mi.mesh, s), mi.cast_shadow]
			if not groups.has(key):
				var st := SurfaceTool.new()
				groups[key] = st
				mats[key] = m
			(groups[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	for key in groups:
		var mesh := ArrayMesh.new()
		(groups[key] as SurfaceTool).commit(mesh)
		if mats[key]:
			mesh.surface_set_material(0, mats[key])
		var out := MeshInstance3D.new()
		out.name = "Batched"
		out.mesh = mesh
		out.cast_shadow = key[2]
		root.add_child(out)
	for mi in cands:
		mi.get_parent().remove_child(mi)
		mi.free()
	return cands.size()


## 멀리서 볼 상품들: 같은 모양·같은 재질끼리 MultiMesh(한 번에 여러 개 그리기)로 묶는다.
## 상품 각자의 메시는 dist 너머에서 숨고, 묶음은 dist 안쪽에서 숨는다. 만드는 데 1ms 정도라 멈칫하지 않는다.
static func bake_far(root: Node3D, prizes_root: Node, old: Node3D, dist: float) -> Node3D:
	if old and is_instance_valid(old):
		old.queue_free()
	var inv := root.global_transform.affine_inverse()
	var groups := {}   # [메시, 재질] → 변환 목록
	var srcs: Array[MeshInstance3D] = []
	for mi in prizes_root.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		if m3.mesh == null or not m3.is_visible_in_tree():
			continue
		srcs.append(m3)
		var key := [m3.mesh, m3.material_override]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(inv * m3.global_transform)
	if srcs.is_empty():
		return null
	var holder := Node3D.new()
	holder.name = "FarPrizes"
	root.add_child(holder)
	for key in groups:
		var xfs: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = key[0]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if key[1]:
			mmi.material_override = key[1]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_begin = dist
		holder.add_child(mmi)
	# 겹치는 구간을 조금 두어 경계에서 인형이 비지 않게(같은 자리라 겹쳐 그려도 티가 나지 않는다)
	# dist 가 0 이면 언제나 묶음만 그린다(진짜 메시는 1cm 너머부터 숨김 = 사실상 숨김)
	for m3 in srcs:
		m3.visibility_range_end = (dist + 0.8) if dist > 0.0 else 0.01
	return holder


## 덩어리를 치우고 모든 상품을 다시 진짜로 그린다(플레이·진열 중)
static func unbake_far(prizes_root: Node, far: Node3D) -> void:
	if far and is_instance_valid(far):
		far.queue_free()
	for mi in prizes_root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = 0.0


## 작은 글씨(가격표·안내문)는 멀리서는 읽을 수도 없으니 dist 너머에서 그리지 않는다(큰 간판은 그대로)
static func hide_small_labels_far(root: Node, dist: float) -> void:
	for l in root.find_children("*", "Label3D", true, false):
		var lab: Label3D = l
		if lab.font_size * lab.pixel_size < 0.06 and lab.visibility_range_end == 0.0:
			lab.visibility_range_end = dist
