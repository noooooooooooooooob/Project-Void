# 원정(Expedition)·게임 상태(GameState) 테스트: 3줄 노드 지도, 연결·선택 규칙, 구역 진행, 체력 이어짐, 보상, 상점, 황혼층, 저장·불러오기.
extends TestCase

const SEEDS: Array[int] = [1, 7, 42, 99]


func run() -> Array[Dictionary]:
	_test_game_state_members_and_decks()
	for s in SEEDS:
		_test_map_shape(s)
		_test_paths_never_cross(s)
		_test_every_node_reaches_the_exit(s)
	_test_first_column_has_battles()
	_test_only_connected_nodes_are_selectable()
	_test_walking_to_the_exit_moves_to_the_next_zone()
	_test_battle_hp_carries_over_and_fallen_rise_with_one()
	_test_encounter_uses_carried_hp_and_enemy_cells()
	_test_rest_heals_and_never_exceeds_max()
	_test_shop_stock_and_spending()
	_test_void_choice_after_zone_three()
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


## 고를 수 있는 첫 노드를 마친다 (전투면 승리 처리).
func _step(ex: Expedition) -> Dictionary:
	var n: Dictionary = ex.pick(ex.selectable_ids()[0])
	if n.has("enemies"):
		ex.resolve_battle_win(n, [30, 25])
	else:
		ex.resolve_simple(n)
	return n


func _clear_zone(ex: Expedition) -> void:
	var zone: int = ex.floor_index
	while ex.floor_index == zone and not ex.finished:
		_step(ex)


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


func _test_map_shape(s: int) -> void:
	var ex: Expedition = _expedition(s)
	var cols: int = ex.column_count()
	check_eq("seed %d: columns × 3 lanes + exit" % s, ex.nodes.size(), cols * Expedition.LANES + 1)
	var exit: Dictionary = ex.node(ex.exit_id())
	check("seed %d: last node is the exit" % s, exit["exit"])
	check_eq("seed %d: exit sits after the last column" % s, exit["col"], cols)
	var shops: int = 0
	for n in ex.nodes:
		if n["type"] == ChapterData.SHOP:
			shops += 1
	check_eq("seed %d: one shop per zone" % s, shops, 1)
	for lane in Expedition.LANES:
		check("seed %d: last column lane %d leads to the exit" % [s, lane], (ex.node((cols - 1) * Expedition.LANES + lane)["next"] as Array) == [ex.exit_id()])


func _test_paths_never_cross(s: int) -> void:
	var ex: Expedition = _expedition(s)
	for c in range(ex.column_count() - 1):
		for lane in range(Expedition.LANES - 1):
			var down: bool = (ex.node(c * 3 + lane)["next"] as Array).has((c + 1) * 3 + lane + 1)
			var up: bool = (ex.node(c * 3 + lane + 1)["next"] as Array).has((c + 1) * 3 + lane)
			check("seed %d: col %d lanes %d/%d don't cross" % [s, c, lane, lane + 1], not (down and up))
		for lane in Expedition.LANES:
			for next_id in ex.node(c * 3 + lane)["next"]:
				var next: Dictionary = ex.node(next_id)
				check("seed %d: edges go one column right and at most one lane" % s, next["col"] == c + 1 and absi(int(next["lane"]) - lane) <= 1)


func _test_every_node_reaches_the_exit(s: int) -> void:
	var ex: Expedition = _expedition(s)
	for n in ex.nodes:
		if n["exit"]:
			continue
		var frontier: Array = [n["id"]]
		var reached: bool = false
		while not frontier.is_empty():
			var id: int = frontier.pop_back()
			if id == ex.exit_id():
				reached = true
				break
			frontier.append_array(ex.node(id)["next"])
		check("seed %d: node %d can reach the exit" % [s, n["id"]], reached)


func _test_first_column_has_battles() -> void:
	for s in 12:
		var ex: Expedition = _expedition(s)
		var battles: int = 0
		for lane in Expedition.LANES:
			if ex.node(lane)["type"] == ChapterData.BATTLE:
				battles += 1
		check_eq("seed %d: first column has two battles" % s, battles, 2)


func _test_only_connected_nodes_are_selectable() -> void:
	var ex: Expedition = _expedition(3)
	check_eq("at the zone start all three first-column nodes are open", ex.selectable_ids(), [0, 1, 2])
	check("a second-column node is not open yet", not ex.is_selectable(3))
	check("picking a closed node returns nothing", ex.pick(4).is_empty())
	var first: Dictionary = ex.pick(1)
	if first.has("enemies"):
		ex.resolve_battle_win(first, [30, 25])
	else:
		ex.resolve_simple(first)
	check_eq("current node moved", ex.current_id, 1)
	var expected: Array[int] = []
	for id in ex.node(1)["next"]:
		expected.append(id)
	expected.sort()
	check_eq("only the connected next nodes are open", ex.selectable_ids(), expected)
	check("the visited node can't be picked again", not ex.is_selectable(1))


func _test_walking_to_the_exit_moves_to_the_next_zone() -> void:
	var ex: Expedition = _expedition()
	var visited_types: Array = []
	while ex.floor_index == 0:
		if ex.at_exit():
			check_eq("only the exit is open at the end", ex.selectable_ids(), [ex.exit_id()])
		visited_types.append(_step(ex)["type"])
	check_eq("one node per column plus the exit", visited_types.size(), ex.column_count() + 1)
	check_eq("now in zone 2", ex.floor_index, 1)
	check_eq("the new zone starts fresh", ex.current_id, -1)
	check("a new map was rolled", ex.visited.is_empty())


func _test_battle_hp_carries_over_and_fallen_rise_with_one() -> void:
	var ex: Expedition = _expedition()
	var n: Dictionary = ex.pick(ex.selectable_ids()[0])
	ex.resolve_battle_win(n, [20, 0])
	check_eq("hp carries over", ex.hp[0], 20)
	check_eq("a fallen member gets up with 1 hp", ex.hp[1], 1)


func _test_encounter_uses_carried_hp_and_enemy_cells() -> void:
	var ex: Expedition = _expedition()
	ex.hp[0] = 12
	var encounter: EncounterData = ex.encounter_for({"type": "battle", "enemies": ["rat", "hound"]})
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
	ex.heal_party(Expedition.REST_HEAL)
	check_eq("rest heals 35%", ex.hp[0], 1 + roundi(max_hp * Expedition.REST_HEAL))
	ex.hp[0] = max_hp
	ex.heal_party(0.5)
	check_eq("never above max", ex.hp[0], max_hp)


func _test_shop_stock_and_spending() -> void:
	var ex: Expedition = _expedition()
	var stock: Dictionary = ex.shop_stock()
	check_eq("three items", stock["items"].size(), 3)
	check_eq("three cards", stock["cards"].size(), 3)
	check("cards have a price", stock["cards"][0]["price"] > 0)
	ex.game.gold = 50
	check("can't buy above the purse", not ex.spend(60))
	check_eq("gold untouched", ex.game.gold, 50)
	check("can buy within the purse", ex.spend(30))
	check_eq("gold spent", ex.game.gold, 20)


func _test_void_choice_after_zone_three() -> void:
	var ex: Expedition = _expedition()
	for f in 3:
		check("no void choice before zone %d is cleared" % (f + 1), not ex.needs_void_choice())
		_clear_zone(ex)
	check("void choice after zone 3", ex.needs_void_choice())
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
