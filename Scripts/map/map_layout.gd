class_name MapLayout
extends RefCounted

const ROW_SPACING: float = 130.0
const COL_SPACING: float = 150.0


static func node_position(node: MapNode) -> Vector2:
	var x: float = float(node.col - MapGraph.COLS / 2) * COL_SPACING
	var y: float = float(node.row + 1) * ROW_SPACING
	return Vector2(x, y)
