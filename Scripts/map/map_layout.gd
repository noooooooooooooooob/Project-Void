class_name MapLayout
extends RefCounted

const STEP_SPACING: float = 120.0
const BRANCH_SPACING: float = 220.0


static func node_position(node: MapNode) -> Vector2:
	if node.branch < 0:
		if node.is_boss:
			return Vector2(0.0, (MapGraph.STEPS_PER_BRANCH + 1) * STEP_SPACING)
		return Vector2.ZERO

	var side: float = -1.0 if node.branch == 0 else 1.0
	var x: float = side * BRANCH_SPACING / 2.0
	var y: float = (node.step + 1) * STEP_SPACING
	return Vector2(x, y)
