extends TestCase

const HudScene := preload("res://Scenes/battle_hud.tscn")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_sync_builds_hand_and_sp()
	_test_interactive_lock()
	_test_turn_bar_text()
	_test_card_selection_signal()
	_test_enemy_turn_clears_hand()
	_test_log_and_banner()
	return results()


func _hud() -> BattleHud:
	var hud: BattleHud = HudScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	return hud


func _card(id: StringName, attack_type: CardData.AttackType, cost: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.id = id
	card.display_name = String(id)
	card.sp_cost = cost
	card.attack_type = attack_type
	card.attack_range = 2
	card.damage = 6
	return card


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 a(속도 10, SP 3) 손패 strike(근접 1) / shot(원거리 1) / big(원거리 9). 적 e(속도 1).
func _started_state() -> BattleState:
	var ally: AllyData = AllyDataScript.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = 3
	var deck: Array[CardData] = [
		_card(&"strike", CardData.AttackType.MELEE, 1),
		_card(&"shot", CardData.AttackType.RANGED, 1),
		_card(&"big", CardData.AttackType.RANGED, 9),
	]
	ally.deck = deck

	var enemy: EnemyData = EnemyDataScript.new()
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = 20
	enemy.speed = 1

	var encounter: EncounterData = EncounterScript.new()
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var state := BattleState.new(encounter, rng)
	state.start_battle()
	return state


func _button_starting_with(hud: BattleHud, prefix: String) -> Button:
	for button in hud.hand_buttons():
		if button.text.begins_with(prefix):
			return button
	return null


func _test_sync_builds_hand_and_sp() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	hud.sync_from_state(state, -1)
	hud.set_interactive(true)

	check_eq("one button per card in hand", hud.hand_buttons().size(), 3)
	check("melee card is labelled", _button_starting_with(hud, "strike  [근접]") != null)
	check("ranged card is labelled", _button_starting_with(hud, "shot  [원거리]") != null)
	check("unaffordable card disabled", _button_starting_with(hud, "big").disabled)
	check("affordable card enabled", not _button_starting_with(hud, "strike").disabled)
	check_eq("sp panel text", hud.sp_text(), "SP\n●●●\n3 / 3")
	check("end turn enabled", hud.end_turn_enabled())
	hud.free()


func _test_interactive_lock() -> void:
	var hud: BattleHud = _hud()
	hud.sync_from_state(_started_state(), -1)
	hud.set_interactive(false)

	var all_disabled: bool = true
	for button in hud.hand_buttons():
		all_disabled = all_disabled and button.disabled
	check("hand locked", all_disabled)
	check("end turn locked", not hud.end_turn_enabled())
	hud.free()


func _test_turn_bar_text() -> void:
	var state: BattleState = _started_state()
	var order: Array[Unit] = state.initiative
	var both_alive: Array[bool] = [true, true]
	var enemy_dead: Array[bool] = [true, false]
	var current: String = BattleHud.turn_bar_text(1, order, both_alive, 0)
	check("current unit marked", current.contains("▶a"))
	var acted: String = BattleHud.turn_bar_text(1, order, both_alive, 1)
	check("acted unit greyed", acted.contains("[color=#%s]a[/color]" % BattleHud.ACTED_COLOR.to_html(false)))
	var dead: String = BattleHud.turn_bar_text(1, order, enemy_dead, 0)
	check("dead unit left out", dead.contains("▶a") and not dead.contains("→"))


func _test_card_selection_signal() -> void:
	var hud: BattleHud = _hud()
	hud.sync_from_state(_started_state(), -1)
	hud.set_interactive(true)
	var picked: Array = []
	hud.card_selected.connect(func(index: int) -> void: picked.append(index))
	var strike: Button = _button_starting_with(hud, "strike")
	var strike_index: int = hud.hand_buttons().find(strike)

	strike.pressed.emit()
	strike.pressed.emit()
	check_eq("select then deselect", picked, [strike_index, -1])
	check("button state follows selection", not strike.button_pressed)
	hud.free()


func _test_enemy_turn_clears_hand() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	hud.sync_from_state(state, -1)
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	event.unit = state.living_units(Unit.Team.ENEMY)[0]
	event.round_index = 1
	event.order = state.initiative
	var alive: Array[bool] = [true, true]
	event.alive = alive
	event.turn_index = 1

	hud.show_turn(event)
	check_eq("hand cleared on enemy turn", hud.hand_buttons().size(), 0)
	check_eq("sp hidden on enemy turn", hud.sp_text(), "")
	hud.free()


func _test_log_and_banner() -> void:
	var hud: BattleHud = _hud()
	hud.append_log("hello")
	check("log keeps lines", hud.log_text().contains("hello"))
	hud.show_banner(false)
	check("banner shown", hud.banner_visible())
	check_eq("defeat banner text", hud.banner_text(), "패배...")
	hud.free()
