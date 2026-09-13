extends TestCase

const ANCHOR := Vector2(576, 538)


func run() -> Array[Dictionary]:
	_test_single_card_sits_on_anchor()
	_test_odd_hand_is_symmetric()
	_test_spread_per_card()
	_test_spread_is_capped()
	return results()


func _test_single_card_sits_on_anchor() -> void:
	var slot: Dictionary = HandLayout.slot(0, 1, ANCHOR)
	check_eq("single card position", slot["position"], ANCHOR)
	check_eq("single card rotation", slot["rotation"], 0.0)


func _test_odd_hand_is_symmetric() -> void:
	var left: Dictionary = HandLayout.slot(0, 5, ANCHOR)
	var middle: Dictionary = HandLayout.slot(2, 5, ANCHOR)
	var right: Dictionary = HandLayout.slot(4, 5, ANCHOR)
	check("middle card on anchor", (middle["position"] as Vector2).is_equal_approx(ANCHOR))
	check("middle card upright", is_equal_approx(middle["rotation"], 0.0))
	check("mirrored horizontally", is_equal_approx(left["position"].x - ANCHOR.x, -(right["position"].x - ANCHOR.x)))
	check("same height on both ends", is_equal_approx(left["position"].y, right["position"].y))
	check("mirrored rotation", is_equal_approx(left["rotation"], -right["rotation"]))
	check("outer cards sit lower than the middle", left["position"].y > ANCHOR.y)


func _test_spread_per_card() -> void:
	check("four cards: first at -9 degrees", is_equal_approx(HandLayout.slot(0, 4, ANCHOR)["rotation"], deg_to_rad(-9.0)))
	check("four cards: last at +9 degrees", is_equal_approx(HandLayout.slot(3, 4, ANCHOR)["rotation"], deg_to_rad(9.0)))


func _test_spread_is_capped() -> void:
	check("ten cards: first capped at -20 degrees", is_equal_approx(HandLayout.slot(0, 10, ANCHOR)["rotation"], deg_to_rad(-20.0)))
	check("ten cards: last capped at +20 degrees", is_equal_approx(HandLayout.slot(9, 10, ANCHOR)["rotation"], deg_to_rad(20.0)))
