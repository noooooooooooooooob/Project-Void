class_name HandLayout
extends RefCounted

const CARD_ANGLE_DEG: float = 6.0
const MAX_SPREAD_DEG: float = 40.0
const RADIUS: float = 900.0


# 반지름 RADIUS 인 원의 꼭대기(anchor)에서 좌우로 부채꼴을 편다. 바깥 카드일수록 조금 아래로 내려간다.
static func slot(index: int, count: int, anchor: Vector2) -> Dictionary:
	if count <= 1:
		return {"position": anchor, "rotation": 0.0}
	var spread: float = minf(CARD_ANGLE_DEG * (count - 1), MAX_SPREAD_DEG)
	var angle: float = deg_to_rad(-spread / 2.0 + spread * float(index) / float(count - 1))
	var offset := Vector2(sin(angle) * RADIUS, (1.0 - cos(angle)) * RADIUS)
	return {"position": anchor + offset, "rotation": angle}
