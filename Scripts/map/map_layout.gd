class_name MapLayout
extends RefCounted

const ROW_SPACING: float = 130.0
const COL_SPACING: float = 150.0


static func node_position(node: MapNode) -> Vector2:
	# 가운데 열 번호를 구하는 나눗셈이라 소수점이 버려지는 게 의도한 동작이다.
	@warning_ignore("integer_division")
	var x: float = float(node.col - MapGraph.COLS / 2) * COL_SPACING
	var y: float = float(node.row + 1) * ROW_SPACING
	return Vector2(x, y)
