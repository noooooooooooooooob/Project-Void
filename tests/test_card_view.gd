extends TestCase

const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")


func run() -> Array[Dictionary]:
	_test_ranged_sweep_card_face()
	_test_melee_single_card_face()
	_test_face_toggle()
	_test_affordable_dimming()
	return results()


func _card(display_name: String, cost: int, attack_type: CardData.AttackType, shape: CardData.Shape, attack_range: int, damage: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.display_name = display_name
	card.sp_cost = cost
	card.attack_type = attack_type
	card.shape = shape
	card.attack_range = attack_range
	card.damage = damage
	return card


func _test_ranged_sweep_card_face() -> void:
	var view := CardView.new()
	view.setup(_card("일제사격", 2, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3))
	check_eq("cost", view.cost_text(), "2")
	check_eq("name", view.name_text(), "일제사격")
	check_eq("damage", view.damage_text(), "3")
	check_eq("footer", view.footer_text(), "원거리 · 사거리 4 · 횡렬")
	check_eq("ranged border", view.border_color(), CardView.RANGED_COLOR)
	check_eq("card size", view.size, CardView.SIZE)
	view.free()


func _test_melee_single_card_face() -> void:
	var view := CardView.new()
	view.setup(_card("베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 2, 6))
	check_eq("melee footer", view.footer_text(), "근접 · 사거리 2 · 단일")
	check_eq("melee border", view.border_color(), CardView.MELEE_COLOR)
	view.free()


func _test_face_toggle() -> void:
	var view := CardView.new()
	view.setup(_card("관통사격", 2, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 3, 5))
	check("starts face up", view.is_face_up())
	view.set_face_up(false)
	check("turned face down", not view.is_face_up())
	view.free()


func _test_affordable_dimming() -> void:
	var view := CardView.new()
	view.setup(_card("베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 2, 6))
	view.set_affordable(false)
	check_eq("unaffordable is dimmed", view.modulate, CardView.UNAFFORDABLE_MODULATE)
	view.set_affordable(true)
	check_eq("affordable is not dimmed", view.modulate, Color.WHITE)
	view.free()
