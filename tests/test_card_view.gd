# CardView(카드 한 장 화면) 테스트: 앞면 글자·배지·범위 미니맵, 분류 색, 계산값 문구, 앞뒷면 전환, SP 부족 흐림.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")
# 아군 데이터 스크립트 (스탯을 담는 데 쓴다).
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	_test_face_without_stats()
	_test_face_with_stats()
	_test_skill_color()
	_test_face_toggle()
	# SP 부족 흐림.
	_test_affordable_dimming()
	return results()


# 스탯 없이 만들면 % 문구, 배지, 분류 색, 미니맵, 카드 크기.
func _test_face_without_stats() -> void:
	# 원거리 세로 3칸 피해 30% 카드.
	var area: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)]
	var card: CardData = Fixtures.damage_card(&"일제사격", CardData.AttackType.RANGED, 30, area, 2)
	var view := CardView.new()
	view.setup(card)
	check_eq("cost", view.cost_text(), "2")
	check_eq("name", view.name_text(), "일제사격")
	check_eq("effect text", view.effect_text(), "피해 30%")
	check_eq("badge", view.badge_text(), "원")
	# 분류 색 (공격).
	check_eq("border is category color", view.border_color(), CardView.CATEGORY_COLORS[CardData.Category.ATTACK])
	check_eq("area marks", view.area_marks(), area)
	check_eq("card size", view.size, CardView.SIZE)
	# 트리 밖 노드는 직접 지운다.
	view.free()


# 스탯을 주면 계산값.
func _test_face_with_stats() -> void:
	# 근접 피해 60%.
	var card: CardData = Fixtures.damage_card(&"베기", CardData.AttackType.MELEE, 60)
	# 공격 12.
	var stats: AllyData = AllyDataScript.new()
	stats.attack = 12
	var view := CardView.new()
	view.setup(card, stats)
	# 7 (12 × 60% = 7.2).
	check_eq("computed effect", view.effect_text(), "피해 7")
	check_eq("melee badge", view.badge_text(), "근")
	check_eq("single area mark", view.area_marks(), [Vector2i.ZERO])
	view.free()


# 스킬 분류는 파란 테두리.
func _test_skill_color() -> void:
	var effects: Array[CardEffect] = [Fixtures.effect(CardEffect.Kind.BLOCK, 50, CardEffect.Target.SELF)]
	var card: CardData = Fixtures.card(&"방어", CardData.AttackType.SELF, effects)
	card.category = CardData.Category.SKILL
	var view := CardView.new()
	view.setup(card)
	check_eq("skill color", view.border_color(), CardView.CATEGORY_COLORS[CardData.Category.SKILL])
	view.free()


# 처음엔 앞면이고 set_face_up(false) 로 뒷면이 되는지.
func _test_face_toggle() -> void:
	var view := CardView.new()
	view.setup(Fixtures.damage_card(&"관통사격", CardData.AttackType.RANGED, 50))
	check("starts face up", view.is_face_up())
	view.set_face_up(false)
	check("turned face down", not view.is_face_up())
	view.free()


# set_affordable(false) 면 흐림 색, true 면 원래 색인지.
func _test_affordable_dimming() -> void:
	var view := CardView.new()
	view.setup(Fixtures.damage_card(&"베기", CardData.AttackType.MELEE, 60))
	view.set_affordable(false)
	check_eq("unaffordable is dimmed", view.modulate, CardView.UNAFFORDABLE_MODULATE)
	view.set_affordable(true)
	check_eq("affordable is not dimmed", view.modulate, Color.WHITE)
	view.free()
