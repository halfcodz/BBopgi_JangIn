class_name Prize
extends Node3D
## 기계 안에 들어가는 상품 1개. 인형이면 여러 부위(RigidBody3D)가 관절로 연결된 래그돌이다.

var prize_id := ""
var display_name := ""
var cost := 0
var bodies: Array[RigidBody3D] = []
var main_body: RigidBody3D
var colorway := 0
var won := false


func get_center() -> Vector3:
	if main_body == null:
		return global_position
	var c := Vector3.ZERO
	var m := 0.0
	for b in bodies:
		c += b.global_position * b.mass
		m += b.mass
	return c / max(m, 0.0001)


func lowest_y() -> float:
	var y := INF
	for b in bodies:
		y = min(y, b.global_position.y)
	return y


func highest_y() -> float:
	var y := -INF
	for b in bodies:
		y = max(y, b.global_position.y)
	return y


func total_mass() -> float:
	var m := 0.0
	for b in bodies:
		m += b.mass
	return m


func is_resting() -> bool:
	for b in bodies:
		if b.linear_velocity.length() > 0.03 or b.angular_velocity.length() > 0.3:
			return false
	return true


func set_frozen(f: bool) -> void:
	for b in bodies:
		b.freeze = f


func wake() -> void:
	for b in bodies:
		b.sleeping = false


## 현재 자세를 그대로 다른 위치로 옮긴다(진열·저장 복원용)
func teleport_to(pos: Vector3, rot_y: float = 0.0) -> void:
	var c := get_center()
	var xf := Transform3D(Basis(Vector3.UP, rot_y), Vector3.ZERO)
	for b in bodies:
		var rel := b.global_position - c
		b.global_transform = Transform3D(xf.basis * b.global_transform.basis, pos + xf.basis * rel)
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO


func save_state() -> Dictionary:
	var parts := []
	for b in bodies:
		var t := b.global_transform
		parts.append([t.origin.x, t.origin.y, t.origin.z,
			t.basis.get_rotation_quaternion().x, t.basis.get_rotation_quaternion().y,
			t.basis.get_rotation_quaternion().z, t.basis.get_rotation_quaternion().w])
	return {"id": prize_id, "colorway": colorway, "parts": parts}


func load_state(d: Dictionary) -> void:
	var parts: Array = d.get("parts", [])
	if parts.size() != bodies.size():
		return
	for i in bodies.size():
		var p: Array = parts[i]
		bodies[i].global_transform = Transform3D(Basis(Quaternion(p[3], p[4], p[5], p[6])), Vector3(p[0], p[1], p[2]))
