extends TestCase

const HudScene := preload("res://Scenes/battle_hud.tscn")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_sync_builds_hand_and_piles()
	_test_interactive_lock()
	_test_turn_bar_text()
	_test_hand_signals_are_relayed()
	_test_enemy_turn_clears_hand_and_dims_piles()
	_test_ally_turn_shows_pile_snapshot()
	_test_playback_helpers()
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


# 아군 a(속도 10, SP 3) 덱 strike(근접 1) / shot(원거리 1) / big(원거리 9) — 시작하면 3장 모두 손패, 덱 0. 적 e(속도 1).
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


func _view_named(views: Array[CardView], display_name: String) -> CardView:
	for view in views:
		if view.card.display_name == display_name:
			return view
	return null


func _turn_event(state: BattleState, unit: Unit, turn_index: int) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	event.unit = unit
	event.round_index = 1
	event.order = state.initiative
	var alive: Array[bool] = [true, true]
	event.alive = alive
	event.turn_index = turn_index
	return event


func _test_sync_builds_hand_and_piles() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	hud.sync_from_state(state, -1)
	hud.set_interactive(true)

	var views: Array[CardView] = hud.hand_view().card_views()
	check_eq("one card view per card in hand", views.size(), 3)
	check_eq("melee card border", _view_named(views, "strike").border_color(), CardView.MELEE_COLOR)
	check_eq("unaffordable card dimmed", _view_named(views, "big").modulate, CardView.UNAFFORDABLE_MODULATE)
	check_eq("sp panel text", hud.sp_text(), "SP\n●●●\n3 / 3")
	check_eq("deck pile names the ally", hud.deck_pile().owner_text(), "a")
	check_eq("deck pile count", hud.deck_pile().count_text(), "0")
	check_eq("discard pile count", hud.discard_pile().count_text(), "0")
	check("end turn enabled", hud.end_turn_enabled())
	hud.free()


func _test_interactive_lock() -> void:
	var hud: BattleHud = _hud()
	hud.sync_from_state(_started_state(), 0)
	hud.set_interactive(true)
	hud.set_interactive(false)
	check("hand locked", not hud.hand_view().interactive)
	check("end turn locked", not hud.end_turn_enabled())
	check_eq("lock clears the selection", hud.hand_view().selected_index(), -1)
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


func _test_hand_signals_are_relayed() -> void:
	var hud: BattleHud = _hud()
	var picked: Array = []
	var dropped: Array = []
	hud.card_selected.connect(func(index: int) -> void: picked.append(index))
	hud.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append([index, at]))
	hud.hand_view().card_selected.emit(1)
	hud.hand_view().card_dropped.emit(0, Vector2(10, 20))
	check_eq("selection relayed", picked, [1])
	check_eq("drop relayed", dropped, [[0, Vector2(10, 20)]])
	hud.free()


func _test_enemy_turn_clears_hand_and_dims_piles() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	hud.sync_from_state(state, -1)
	hud.show_turn(_turn_event(state, state.living_units(Unit.Team.ENEMY)[0], 1))
	check_eq("hand cleared on enemy turn", hud.hand_view().card_views().size(), 0)
	check_eq("sp hidden on enemy turn", hud.sp_text(), "")
	check("piles dimmed on enemy turn", hud.deck_pile().is_dimmed())
	hud.free()


func _test_ally_turn_shows_pile_snapshot() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	var event: BattleEvent = _turn_event(state, state.living_units(Unit.Team.ALLY)[0], 0)
	event.deck_count = 5
	event.discard_count = 2
	hud.show_turn(event)
	check_eq("deck owner is the acting ally", hud.deck_pile().owner_text(), "a")
	check_eq("deck count from snapshot", hud.deck_pile().count_text(), "5")
	check_eq("discard count from snapshot", hud.discard_pile().count_text(), "2")
	check("piles lit on ally turn", not hud.deck_pile().is_dimmed())
	hud.free()


func _test_playback_helpers() -> void:
	var hud: BattleHud = _hud()
	var state: BattleState = _started_state()
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	hud.sync_from_state(state, -1)

	var drawn := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
	drawn.unit = ally
	drawn.card = ally.hand[0]
	drawn.deck_count = 1
	drawn.discard_count = 0
	hud.draw_card(drawn)
	check_eq("drawn card joins the hand", hud.hand_view().card_views().size(), 4)
	check_eq("deck count after draw", hud.deck_pile().count_text(), "1")

	var played := BattleEvent.new(BattleEvent.Kind.CARD_PLAYED)
	played.unit = ally
	played.card = ally.hand[0]
	played.deck_count = 1
	played.discard_count = 1
	hud.set_pending_play(0)
	hud.remove_played_card(played)
	check_eq("played card leaves the hand", hud.hand_view().card_views().size(), 3)
	check_eq("discard count after play", hud.discard_pile().count_text(), "1")

	var discarded := BattleEvent.new(BattleEvent.Kind.HAND_DISCARDED)
	discarded.unit = ally
	discarded.discard_count = 4
	discarded.deck_count = 1
	hud.discard_hand(discarded)
	check_eq("hand empty after discard", hud.hand_view().card_views().size(), 0)
	check_eq("discard count after discard", hud.discard_pile().count_text(), "4")

	var reshuffled := BattleEvent.new(BattleEvent.Kind.DECK_RESHUFFLED)
	reshuffled.unit = ally
	reshuffled.amount = 4
	reshuffled.deck_count = 5
	reshuffled.discard_count = 0
	hud.reshuffle(reshuffled)
	check_eq("deck refilled", hud.deck_pile().count_text(), "5")
	check_eq("discard emptied", hud.discard_pile().count_text(), "0")
	hud.free()


func _test_log_and_banner() -> void:
	var hud: BattleHud = _hud()
	hud.append_log("hello")
	check("log keeps lines", hud.log_text().contains("hello"))
	hud.show_banner(false)
	check("banner shown", hud.banner_visible())
	check_eq("defeat banner text", hud.banner_text(), "패배...")
	hud.free()
