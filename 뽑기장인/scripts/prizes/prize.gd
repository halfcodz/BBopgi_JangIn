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
		b.reset_physics_interpolation()


## ref: 기계의 global_transform. 기계 기준(로컬) 좌표로 저장해야 가게 배치가 바뀌어도 상품이 기계 안에 그대로 남는다.
func save_state(ref: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var parts := []
	var inv := ref.affine_inverse()
	for b in bodies:
		var t := inv * b.global_transform
		var q := t.basis.get_rotation_quaternion()
		parts.append([t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w])
	return {"id": prize_id, "colorway": colorway, "parts": parts, "space": "local"}


func load_state(d: Dictionary, ref: Transform3D = Transform3D.IDENTITY) -> void:
	var parts: Array = d.get("parts", [])
	if parts.size() != bodies.size():
		return
	var base := ref if String(d.get("space", "")) == "local" else Transform3D.IDENTITY
	for i in bodies.size():
		var p: Array = parts[i]
		bodies[i].global_transform = base * Transform3D(Basis(Quaternion(p[3], p[4], p[5], p[6]).normalized()), Vector3(p[0], p[1], p[2]))
		bodies[i].reset_physics_interpolation()
