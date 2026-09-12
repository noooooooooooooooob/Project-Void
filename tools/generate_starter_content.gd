extends SceneTree


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://Resources/cards")
	DirAccess.make_dir_recursive_absolute("res://Resources/units")

	var cards: Dictionary = _make_cards()
	for card_id in cards:
		_save(cards[card_id], "res://Resources/cards/%s.tres" % card_id)

	for unit in _make_units(cards):
		_save(unit, "res://Resources/units/%s.tres" % unit.id)

	print("starter content generated")
	quit(0)


func _save(resource: Resource, path: String) -> void:
	var err: int = ResourceSaver.save(resource, path)
	if err != OK:
		push_error("failed to save %s (error %d)" % [path, err])
	else:
		print("  wrote %s" % path)


func _card(id: StringName, name: String, sp: int, attack_type: int, shape: int, attack_range: int, damage: int) -> CardData:
	var card := CardData.new()
	card.id = id
	card.display_name = name
	card.sp_cost = sp
	card.attack_type = attack_type
	card.shape = shape
	card.attack_range = attack_range
	card.damage = damage
	return card


func _make_cards() -> Dictionary:
	return {
		"strike": _card(&"strike", "베기", 1, CardData.AttackType.MELEE, CardData.Shape.SINGLE, 1, 6),
		"cleave": _card(&"cleave", "횡베기", 2, CardData.AttackType.MELEE, CardData.Shape.SWEEP, 1, 4),
		"shoot": _card(&"shoot", "사격", 1, CardData.AttackType.RANGED, CardData.Shape.SINGLE, 3, 4),
		"volley": _card(&"volley", "일제사격", 2, CardData.AttackType.RANGED, CardData.Shape.SWEEP, 4, 3),
		"piercing_shot": _card(&"piercing_shot", "관통사격", 2, CardData.AttackType.RANGED, CardData.Shape.PIERCE, 3, 5),
	}


func _make_units(cards: Dictionary) -> Array[UnitData]:
	var vanguard := AllyData.new()
	vanguard.id = &"vanguard"
	vanguard.display_name = "선봉"
	vanguard.max_hp = 30
	vanguard.speed = 12
	vanguard.max_sp = 3
	vanguard.deck = _deck([cards["strike"], cards["strike"], cards["strike"], cards["cleave"], cards["cleave"], cards["shoot"]])

	var archer := AllyData.new()
	archer.id = &"archer"
	archer.display_name = "사수"
	archer.max_hp = 20
	archer.speed = 10
	archer.max_sp = 3
	archer.deck = _deck([cards["shoot"], cards["shoot"], cards["shoot"], cards["volley"], cards["piercing_shot"], cards["piercing_shot"]])

	var scout := AllyData.new()
	scout.id = &"scout"
	scout.display_name = "정찰병"
	scout.max_hp = 22
	scout.speed = 16
	scout.max_sp = 2
	scout.deck = _deck([cards["strike"], cards["strike"], cards["shoot"], cards["shoot"], cards["volley"], cards["cleave"]])

	var brute := EnemyData.new()
	brute.id = &"brute"
	brute.display_name = "괴한"
	brute.max_hp = 28
	brute.speed = 8
	brute.attack_damage = 7
	brute.attack_type = CardData.AttackType.MELEE
	brute.attack_shape = CardData.Shape.SINGLE
	brute.attack_range = 1
	brute.block_amount = 6
	brute.rest_heal = 5

	var stalker := EnemyData.new()
	stalker.id = &"stalker"
	stalker.display_name = "추적자"
	stalker.max_hp = 18
	stalker.speed = 14
	stalker.attack_damage = 4
	stalker.attack_type = CardData.AttackType.RANGED
	stalker.attack_shape = CardData.Shape.PIERCE
	stalker.attack_range = 3
	stalker.block_amount = 4
	stalker.rest_heal = 4

	var sentry := EnemyData.new()
	sentry.id = &"sentry"
	sentry.display_name = "보초"
	sentry.max_hp = 24
	sentry.speed = 6
	sentry.attack_damage = 5
	sentry.attack_type = CardData.AttackType.RANGED
	sentry.attack_shape = CardData.Shape.SWEEP
	sentry.attack_range = 4
	sentry.block_amount = 8
	sentry.rest_heal = 3

	var out: Array[UnitData] = []
	out.append_array([vanguard, archer, scout, brute, stalker, sentry])
	return out


func _deck(cards: Array) -> Array[CardData]:
	var typed: Array[CardData] = []
	typed.append_array(cards)
	return typed
