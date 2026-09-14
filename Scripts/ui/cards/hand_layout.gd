## 손패 부채꼴 배치 계산 (노드 없음, 순수 계산).
## 카드 수와 몇 번째 카드인지로 그 카드가 놓일 위치와 기울기를 구한다.
class_name HandLayout
# RefCounted: 노드가 아닌 가벼운 객체. 함수가 static 이라 객체를 만들 필요는 없다.
extends RefCounted

## 이웃한 카드 사이의 기울기 차이 (도).
const CARD_ANGLE_DEG: float = 6.0
## 부채꼴 전체가 펼쳐질 수 있는 최대 각도 (도). 카드가 많아도 이 이상 벌어지지 않는다.
const MAX_SPREAD_DEG: float = 40.0
## 부채꼴이 올라타는 가상의 원 반지름 (픽셀). 클수록 완만한 곡선이 된다.
const RADIUS: float = 900.0


# 반지름 RADIUS 인 원의 꼭대기(anchor)에서 좌우로 부채꼴을 편다. 바깥 카드일수록 조금 아래로 내려간다.
## index 번째 카드(전체 count 장)의 중심 위치와 회전(라디안)을 {"position", "rotation"} 로 돌려준다.
static func slot(index: int, count: int, anchor: Vector2) -> Dictionary:
	# 카드가 한 장 이하면 기울이지 않고 가운데에 둔다 (count - 1 로 나누는 것도 피한다).
	if count <= 1:
		return {"position": anchor, "rotation": 0.0}
	# 전체 펼침 각도 = 카드 간격 × (장수 - 1), 단 최대치를 넘지 않는다.
	var spread: float = minf(CARD_ANGLE_DEG * (count - 1), MAX_SPREAD_DEG)
	# 왼쪽 끝(-spread/2)에서 오른쪽 끝(+spread/2)까지 균등하게 나눈 이 카드의 각도.
	var angle: float = deg_to_rad(-spread / 2.0 + spread * float(index) / float(count - 1))
	# 원 위의 점: 가로는 sin 만큼 옆으로, 세로는 (1 - cos) 만큼 아래로 (각도가 클수록 더 내려감).
	var offset := Vector2(sin(angle) * RADIUS, (1.0 - cos(angle)) * RADIUS)
	# 위치와 기울기(원의 접선 방향과 같게 각도 그대로)를 돌려준다.
	return {"position": anchor + offset, "rotation": angle}
