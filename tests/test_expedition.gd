# 원정(Expedition)·게임 상태(GameState) 테스트: 층·노드 진행, 체력 이어짐, 보상, 황혼층, 저장·불러오기.
extends TestCase


func run() -> Array[Dictionary]:
	_test_game_state_members_and_decks()
	_test_first_step_always_offers_a_battle()
	_test_floor_exit_and_progression()
	_test_battle_hp_carries_over_and_fallen_rise_with_one()
	_test_encounter_uses_carried_hp_and_enemy_cells()
	_test_rest_heals_and_never_exceeds_max()
	_test_void_choice_after_floor_three()
	_test_deep_layer_scales_enemies()
	_test_rewards_offer_member_cards()
	_test_save_round_trip()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _game() -> GameState:
	var game := GameState.new()
	game.add_member("hangyeol")
	game.add_member("hongyeon")
	return game


func _expedition(seed_value: int = 1) -> Expedition:
	return Expedition.new(ChapterData.CHAPTER1, _game(), _rng(seed_value))


func _test_game_state_members_and_decks() -> void:
	var game: GameState = _game()
	check_eq("two members", game.party.member_count(), 2)
	check("adding the same member twice is refused", not game.add_member("hongyeon"))
	var base: AllyData = load("res://Resources/content/units/hangyeol.tres")
	var size_before: int = base.deck.size()
	game.add_card(0, load("res://Resources/content/cards/heavy_cut.tres"))
	check_eq("the member's deck grows", game.party.member_data(0).deck.size(), size_before + 1)
	check_eq("the source .tres deck is untouched", (load("res://Resources/content/units/hangyeol.tres") as AllyData).deck.size(), size_before)
	check("hongyeon has her passives", game.party.member_data(1).passives.has(BattleState.BLOOD_ARMOR))


func _test_first_step_always_offers_a_battle() -> void:
	for s in 15:
		var ex: Expedition = _expedition(s)
		var types: Array = []
		for o in ex.options:
			types.append(o["type"])
		check("seed %d: first doors include a battle" % s, types.has("battle"))
		check("seed %d: 2~3 doors" % s, ex.options.size() >= 2 and ex.options.size() <= 3)


func _test_floor_exit_and_progression() -> void:
	var ex: Expedition = _expedition()
	for i in ex.steps_per_floor():
		ex.resolve_simple()
	check("after the steps comes the exit", ex.at_exit())
	check_eq("exit is a single battle node", ex.options.size(), 1)
	check_eq("floor 1 exit is a plain battle", ex.options[0]["type"], "battle")
	ex.resolve_battle_win(ex.options[0], [30, 25])
	check_eq("now on floor 2", ex.floor_index, 1)
	check_eq("back to step 0", ex.step, 0)


func _test_battle_hp_carries_over_and_fallen_rise_with_one() -> void:
	var ex: Expedition = _expedition()
	ex.resolve_battle_win(ex.options[0], [20, 0])
	check_eq("hp carries over", ex.hp[0], 20)
	check_eq("a fallen member gets up with 1 hp", ex.hp[1], 1)


func _test_encounter_uses_carried_hp_and_enemy_cells() -> void:
	var ex: Expedition = _expedition()
	ex.hp[0] = 12
	var node: Dictionary = {"type": "battle", "enemies": ["rat", "hound"]}
	var encounter: EncounterData = ex.encounter_for(node)
	check_eq("ally starts with carried hp", encounter.ally_units[0].start_hp, 12)
	check_eq("two enemies", encounter.enemy_units.size(), 2)
	check_eq("first enemy stands front centre", encounter.enemy_units[0].cell, Vector2i(0, 1))
	check("the sewer room is used", encounter.room != null and encounter.room.backdrop != null)
	var state := BattleState.new(encounter, _rng(1))
	check_eq("battle state starts from carried hp", state.units[0].hp, 12)


func _test_rest_heals_and_never_exceeds_max() -> void:
	var ex: Expedition = _expedition()
	var max_hp: int = ex.game.party.stats(0)["max_hp"]
	ex.hp[0] = 1
	ex.resolve_rest()
	check_eq("rest heals 35%", ex.hp[0], 1 + roundi(max_hp * Expedition.REST_HEAL))
	ex.hp[0] = max_hp
	ex.heal_party(0.5)
	check_eq("never above max", ex.hp[0], max_hp)


func _test_void_choice_after_floor_three() -> void:
	var ex: Expedition = _expedition()
	for f in 3:
		check("no void choice before floor %d is cleared" % (f + 1), not ex.needs_void_choice())
		for i in ex.steps_per_floor():
			ex.resolve_simple()
		ex.resolve_battle_win(ex.options[0], [30, 25])
	check("void choice after floor 3", ex.needs_void_choice())
	ex.choose_deep(true)
	check("choice is made once", not ex.needs_void_choice())
	check("went deeper", ex.deep)


func _test_deep_layer_scales_enemies() -> void:
	var ex: Expedition = _expedition()
	var base: EnemyData = load("res://Resources/content/units/rat.tres")
	ex.deep = true
	var encounter: EncounterData = ex.encounter_for({"type": "battle", "enemies": ["rat"]})
	var scaled: EnemyData = encounter.enemy_units[0].unit_data
	check_eq("deeper enemies have more hp", scaled.max_hp, roundi(base.max_hp * Expedition.DEEP_ENEMY_SCALE))
	check_eq("the source rat is untouched", (load("res://Resources/content/units/rat.tres") as EnemyData).max_hp, base.max_hp)
	check_eq("deeper battles use the twilight room", encounter.room.resource_path, "res://Resources/content/rooms/twilight.tres")


func _test_rewards_offer_member_cards() -> void:
	var ex: Expedition = _expedition()
	var reward: Dictionary = ex.battle_reward({"type": "elite"})
	check("gold is positive", reward["gold"] > 0)
	check_eq("three card choices", reward["cards"].size(), 3)
	for choice in reward["cards"]:
		var member_id: String = String(ex.game.party.member_data(choice["member"]).id)
		check("card %s belongs to %s's pool" % [choice["card"].id, member_id], ChapterData.REWARD_CARDS[member_id].has(String(choice["card"].id)))
	check("elites drop an item", reward["item"] != null)


func _test_save_round_trip() -> void:
	var game: GameState = _game()
	game.chapter = 1
	game.flags["met_hyeolgwi"] = true
	game.add_gold(77)
	game.spend_lifespan(2)
	game.add_card(1, load("res://Resources/content/cards/red_fox.tres"))
	var item: ItemData = ItemPool.load_all()[0]
	game.party.add_item(item)
	game.party.equip(0, item)
	game.add_journal("첫 의뢰", "하수도")
	var copy: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(game.to_dict())))
	check_eq("chapter", copy.chapter, 1)
	check("flags", copy.flags.has("met_hyeolgwi"))
	check_eq("gold", copy.gold, 77)
	check_eq("lifespan", copy.lifespan, GameState.START_LIFESPAN - 2)
	check_eq("members", copy.party.member_count(), 2)
	check_eq("deck with the new card", copy.party.member_data(1).deck.size(), game.party.member_data(1).deck.size())
	check("equipment restored", copy.party.equipped(0, item.slot) != null and copy.party.equipped(0, item.slot).id == item.id)
	check_eq("journal", copy.journal.size(), 1)
