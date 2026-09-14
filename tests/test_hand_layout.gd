# HandLayout(부채꼴 배치 계산) 테스트.
extends TestCase

# 테스트에 쓸 부채꼴 중심점 (1152×648 화면에서 아래 110px 위 가운데).
const ANCHOR := Vector2(576, 538)


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 한 장이면 중심에 똑바로.
	_test_single_card_sits_on_anchor()
	# 홀수 장이면 좌우 대칭.
	_test_odd_hand_is_symmetric()
	# 카드당 6도씩 벌어짐.
	_test_spread_per_card()
	# 최대 40도에서 멈춤.
	_test_spread_is_capped()
	# 결과를 돌려준다.
	return results()


# 카드가 한 장이면 기울지 않고 중심점에 놓이는지.
func _test_single_card_sits_on_anchor() -> void:
	# 1장 중 0번째 자리.
	var slot: Dictionary = HandLayout.slot(0, 1, ANCHOR)
	# 위치가 중심점과 같은지.
	check_eq("single card position", slot["position"], ANCHOR)
	# 기울기가 0 인지.
	check_eq("single card rotation", slot["rotation"], 0.0)


# 5장일 때 가운데 카드는 중심에 똑바로, 양 끝은 좌우·기울기가 거울처럼 대칭이고 가운데보다 낮은지.
func _test_odd_hand_is_symmetric() -> void:
	# 왼쪽 끝 카드.
	var left: Dictionary = HandLayout.slot(0, 5, ANCHOR)
	# 가운데 카드.
	var middle: Dictionary = HandLayout.slot(2, 5, ANCHOR)
	# 오른쪽 끝 카드.
	var right: Dictionary = HandLayout.slot(4, 5, ANCHOR)
	# 가운데 카드는 중심점에.
	check("middle card on anchor", (middle["position"] as Vector2).is_equal_approx(ANCHOR))
	# 가운데 카드는 똑바로.
	check("middle card upright", is_equal_approx(middle["rotation"], 0.0))
	# 양 끝의 중심에서 가로 거리가 부호만 반대.
	check("mirrored horizontally", is_equal_approx(left["position"].x - ANCHOR.x, -(right["position"].x - ANCHOR.x)))
	# 양 끝의 높이가 같다.
	check("same height on both ends", is_equal_approx(left["position"].y, right["position"].y))
	# 양 끝의 기울기가 부호만 반대.
	check("mirrored rotation", is_equal_approx(left["rotation"], -right["rotation"]))
	# 끝 카드는 중심보다 아래(y 가 더 큼).
	check("outer cards sit lower than the middle", left["position"].y > ANCHOR.y)


# 4장이면 전체 18도(6도 × 3)이므로 양 끝이 ±9도인지.
func _test_spread_per_card() -> void:
	# 첫 카드 -9도.
	check("four cards: first at -9 degrees", is_equal_approx(HandLayout.slot(0, 4, ANCHOR)["rotation"], deg_to_rad(-9.0)))
	# 마지막 카드 +9도.
	check("four cards: last at +9 degrees", is_equal_approx(HandLayout.slot(3, 4, ANCHOR)["rotation"], deg_to_rad(9.0)))


# 10장이면 6도 × 9 = 54도지만 최대 40도로 제한되어 양 끝이 ±20도인지.
func _test_spread_is_capped() -> void:
	# 첫 카드 -20도.
	check("ten cards: first capped at -20 degrees", is_equal_approx(HandLayout.slot(0, 10, ANCHOR)["rotation"], deg_to_rad(-20.0)))
	# 마지막 카드 +20도.
	check("ten cards: last capped at +20 degrees", is_equal_approx(HandLayout.slot(9, 10, ANCHOR)["rotation"], deg_to_rad(20.0)))
