# 밸런스 확인용: 아군을 단순 AI 로 조작해 의뢰를 끝까지 여러 번 돌리고 승률·체력·라운드를 출력한다.
# 실행: Godot --headless --path <프로젝트> --script res://tools/simulate_chapter.gd -- [의뢰 id] [횟수] [deep]
extends SceneTree

const MAX_ROUNDS: int = 40


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var request_id: String = args[0] if args.size() > 0 else "ch1"
	var runs: int = int(args[1]) if args.size() > 1 else 20
	var force_deep: bool = args.size() > 2 and args[2] == "deep"
	var request: Dictionary = ChapterData.get_request(request_id)
	var clears: int = 0
	var floor_reached: Array[int] = []
	var rounds_total: int = 0
	var battles_total: int = 0
	var deaths_at: Dictionary = {}
	for run in runs:
		var game := GameState.new()
		game.add_member("hangyeol")
		game.add_member("hongyeon")
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + run
		var ex := Expedition.new(request, game, rng)
		var alive: bool = true
		while not ex.finished and alive:
			if ex.needs_void_choice():
				ex.choose_deep(force_deep)
			var node: Dictionary = _pick(ex)
			match node["type"]:
				"battle", "elite", "boss":
					var result: Dictionary = _battle(ex.encounter_for(node), 7 + run)
					rounds_total += result["rounds"]
					battles_total += 1
					if result["won"]:
						# 보상 카드는 첫 번째를 고른다.
						var reward: Dictionary = ex.battle_reward(node)
						if not reward["cards"].is_empty():
							game.add_card(reward["cards"][0]["member"], reward["cards"][0]["card"])
						ex.resolve_battle_win(node, result["hp"])
					else:
						var key: String = "F%d %s %s" % [ex.floor_index + 1, node["type"], ",".join(node["enemies"])]
						deaths_at[key] = int(deaths_at.get(key, 0)) + 1
						alive = false
				"rest":
					ex.resolve_rest()
				_:
					ex.resolve_simple()
		floor_reached.append(ex.floor_index + (1 if ex.finished else 0))
		if ex.outcome == "clear":
			clears += 1
	print("request=%s runs=%d deep=%s clears=%d (%.0f%%)" % [request_id, runs, force_deep, clears, 100.0 * clears / runs])
	print("avg rounds per battle: %.1f over %d battles" % [float(rounds_total) / maxf(battles_total, 1), battles_total])
	print("floors reached: %s" % [floor_reached])
	print("defeats: %s" % [deaths_at])
	quit()


## 전투를 우선 고르고, 체력이 낮으면 휴식을 고른다.
func _pick(ex: Expedition) -> Dictionary:
	var low: bool = ex.hp_ratio(0) < 0.5 or ex.hp_ratio(1) < 0.5
	for i in ex.options.size():
		if low and ex.options[i]["type"] == "rest":
			ex.options = [ex.options[i]]
			return ex.options[0]
	for i in ex.options.size():
		if ex.options[i]["type"] == "battle":
			return ex.options[i]
	return ex.options[0]


func _battle(encounter: EncounterData, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := BattleState.new(encounter, rng)
	state.start_battle()
	while not state.finished and state.round_index <= MAX_ROUNDS:
		_ally_turn(state)
		if not state.finished:
			state.end_turn()
	var hp: Array = []
	for u in state.units:
		if u.is_ally():
			hp.append(u.hp)
	return {"won": state.finished and state.ally_won, "rounds": state.round_index, "hp": hp}


func _ally_turn(state: BattleState) -> void:
	var actor: Unit = state.current_unit()
	if actor == null or not actor.is_ally():
		return
	var moved: bool = false
	var guard: int = 0
	while guard < 12:
		guard += 1
		var played: bool = false
		# 비싼 카드부터.
		var order: Array = range(actor.hand.size())
		order.sort_custom(func(a: int, b: int) -> bool: return actor.hand[a].sp_cost > actor.hand[b].sp_cost)
		for i in order:
			if i >= actor.hand.size():
				continue
			var card: CardData = actor.hand[i]
			if card.sp_cost > actor.sp:
				continue
			var anchors: Array[Unit] = state.resolver.valid_anchors(actor, card, state.units)
			if anchors.is_empty():
				continue
			var target: Unit = anchors[0]
			for a in anchors:
				if a.hp < target.hp:
					target = a
			if state.play_card(i, target):
				played = true
				break
		if state.finished:
			return
		if not played:
			# 근접 대상이 없으면 적이 있는 행으로 움직여 본다.
			if not moved and state.resolver.melee_anchor(actor, state.units) == null:
				moved = true
				for cell in state.resolver.reachable_cells(actor, state.units, actor.move_points):
					for e in state.living_units(Unit.Team.ENEMY):
						if e.cell.y == cell.y:
							state.move_unit(cell)
							break
					if actor.cell == cell:
						break
				continue
			return
