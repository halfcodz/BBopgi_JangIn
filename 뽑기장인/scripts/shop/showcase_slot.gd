class_name ShowcaseSlot
extends Node3D
## 전시장 칸 하나: 바라보고 E 를 누르면 확대 보기가 열린다.

var entry_index := 0
var prize_name := ""


func interact_prompt() -> String:
	return "[E] %s 자세히 보기 (돌려 보기·확대)" % prize_name


func interact(_player) -> void:
	var main = get_tree().current_scene
	if main and main.get("hud"):
		main.hud.open_inspector(entry_index)
