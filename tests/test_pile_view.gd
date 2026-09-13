extends TestCase


func run() -> Array[Dictionary]:
	_test_labels()
	_test_dimming()
	_test_center()
	return results()


func _test_labels() -> void:
	var pile := PileView.new()
	check_eq("starts at zero", pile.count_text(), "0")
	pile.set_count(7)
	check_eq("count text", pile.count_text(), "7")
	pile.set_owner_name("선봉")
	check_eq("owner text", pile.owner_text(), "선봉")
	pile.free()


func _test_dimming() -> void:
	var pile := PileView.new()
	pile.set_dimmed(true)
	check("dimmed", pile.is_dimmed())
	pile.set_dimmed(false)
	check("not dimmed", not pile.is_dimmed())
	pile.free()


func _test_center() -> void:
	var pile := PileView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(pile)
	pile.position = Vector2(100, 200)
	check("center of the pile in viewport coordinates", pile.center_global().is_equal_approx(Vector2(145, 263)))
	pile.free()
