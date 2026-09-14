# CardView(카드 한 장 화면) 테스트: 앞면 글자, 테두리 색, 앞뒷면 전환, SP 부족 흐림.
extends TestCase

# 테스트용 카드를 코드로 만들기 위한 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 원거리·횡렬 카드 앞면.
	_test_ranged_sweep_card_face()
	# 근접·단일 카드 앞면.
	_test_melee_single_card_face()
	# 앞뒷면 전환.
	_test_face_toggle()
	# SP 부족 흐림.
	_test_affordable_dimming()
	# 결과를 돌려준다.
	return results()


# 주어진 값으로 테스트용 카드 데이터를 만든다.
func _card(display_name: String, cost: int, attack_type: CardData.AttackType, shape: CardData.Shape, attack_range: int, damage: int) -> CardData:
	# 빈 카드.
	var card: CardData = CardDataScript.new()
	# 이름.
	card.display_name = display_name
	# 비용.
	card.sp_cost = cost
	# 공격 방식.
	card.attack_type = attack_type
	# 범위 모양.
	card.shape = shape
	# 사거리.
	card.attack_range = attack_range
	# 피해.
	card.damage = damage
	# 만든 카드를 돌려준다.
	return card


# 원거리 횡렬 카드: 비용·이름·피해·아래 두 줄 글자·푸른 테두리·카드 크기가 맞는지.
func _test_ranged_sweep_card_face() -> void:
	# 카드 화면을 만든다.
	var view := CardView.new()
	# 일제사격(비용 2, 원거리, 횡렬, 사거리 4, 피해 3) 으로 채운다.
	view.setup(_card("일제사격", 2, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3))
	# 비용 글자.
	check_eq("cost", view.cost_text(), "2")
	# 이름 글자.
	check_eq("name", view.name_text(), "일제사격")
	# 피해 글자.
	check_eq("damage", view.damage_text(), "3")
	# 아래 두 줄 글자.
	check_eq("footer", view.footer_text(), "사거리 4\n원거리 · 횡렬")
	# 원거리 테두리 색.
	check_eq("ranged border", view.border_color(), CardView.RANGED_COLOR)
	# 크기.
	check_eq("card size", view.size, CardView.SIZE)
	# 트리 밖 노드는 직접 지운다.
	view.free()


# 근접 단일 카드: 아래 글자와 붉은 테두리.
func _test_melee_single_card_face() -> void:
	# 카드 화면을 만든다.
	var view := CardView.new()
	# 베기(비용 1, 근접, 단일, 사거리 2, 피해 6) 으로 채운다.
	view.setup(_card("베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 2, 6))
	# 아래 두 줄 글자.
	check_eq("melee footer", view.footer_text(), "사거리 2\n근접 · 단일")
	# 근접 테두리 색.
	check_eq("melee border", view.border_color(), CardView.MELEE_COLOR)
	# 지운다.
	view.free()


# 처음엔 앞면이고 set_face_up(false) 로 뒷면이 되는지.
func _test_face_toggle() -> void:
	# 카드 화면을 만든다.
	var view := CardView.new()
	# 관통사격 카드로 채운다.
	view.setup(_card("관통사격", 2, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 3, 5))
	# 앞면으로 시작.
	check("starts face up", view.is_face_up())
	# 뒷면으로 뒤집는다.
	view.set_face_up(false)
	# 뒷면인지.
	check("turned face down", not view.is_face_up())
	# 지운다.
	view.free()


# set_affordable(false) 면 흐림 색, true 면 원래 색인지.
func _test_affordable_dimming() -> void:
	# 카드 화면을 만든다.
	var view := CardView.new()
	# 베기 카드로 채운다.
	view.setup(_card("베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 2, 6))
	# 쓸 수 없음으로.
	view.set_affordable(false)
	# 흐림 색이 곱해졌는지.
	check_eq("unaffordable is dimmed", view.modulate, CardView.UNAFFORDABLE_MODULATE)
	# 쓸 수 있음으로.
	view.set_affordable(true)
	# 원래 색인지.
	check_eq("affordable is not dimmed", view.modulate, Color.WHITE)
	# 지운다.
	view.free()
