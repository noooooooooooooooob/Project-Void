# 범위 편집기 격자 계산: 칸 번호 ↔ 오프셋, 토글.
extends TestCase

# 격자 계산 스크립트 (에디터 밖에서도 불러올 수 있다).
const AreaGridLogic := preload("res://addons/card_area_editor/area_grid_logic.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 칸 번호.
	_test_offsets()
	# 토글.
	_test_toggle()
	# 결과를 돌려준다.
	return results()


# 0 → (-2,-2), 12 → (0,0), 24 → (2,2), 7 → (0,-1).
func _test_offsets() -> void:
	# 모서리와 가운데.
	check_eq("index 0", AreaGridLogic.offset_for(0), Vector2i(-2, -2))
	check_eq("index 12 is center", AreaGridLogic.offset_for(12), Vector2i(0, 0))
	check_eq("index 24", AreaGridLogic.offset_for(24), Vector2i(2, 2))
	check_eq("index 7", AreaGridLogic.offset_for(7), Vector2i(0, -1))


# 없는 칸은 뒤에 붙고, 있는 칸은 빠지며, 원본은 바뀌지 않는다.
func _test_toggle() -> void:
	# 원본.
	var area: Array[Vector2i] = [Vector2i(0, 0)]
	# 켠다.
	var on: Array[Vector2i] = AreaGridLogic.toggled(area, Vector2i(1, 0))
	check_eq("toggle on appends", on, [Vector2i(0, 0), Vector2i(1, 0)])
	# 끈다.
	check_eq("toggle off removes", AreaGridLogic.toggled(on, Vector2i(0, 0)), [Vector2i(1, 0)])
	# 원본 그대로.
	check_eq("source untouched", area, [Vector2i(0, 0)])
