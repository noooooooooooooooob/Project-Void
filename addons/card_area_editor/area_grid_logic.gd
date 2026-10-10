# @tool: 에디터 플러그인이 쓴다.
@tool
## 범위 편집기 5×5 격자 계산 (에디터 API 없이 순수 계산만 — 테스트에서 직접 불러온다).
extends RefCounted

## 격자 한 변 칸 수 (오프셋 −2~+2).
const SIZE: int = 5


## 칸 번호(왼쪽 위 0, 오른쪽으로 증가) → 오프셋. 가운데 칸이 (0,0).
static func offset_for(index: int) -> Vector2i:
	# 가운데 번호.
	var center: int = SIZE / 2
	# 열·행에서 가운데를 뺀다.
	return Vector2i(index % SIZE - center, index / SIZE - center)


## area 에서 offset 을 켜거나 끈 새 배열 (원본은 바꾸지 않는다).
static func toggled(area: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
	# 복사본.
	var result: Array[Vector2i] = area.duplicate()
	# 있으면 빼고, 없으면 붙인다.
	if result.has(offset):
		result.erase(offset)
	else:
		result.append(offset)
	# 돌려준다.
	return result
