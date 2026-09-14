# BattleHud 테스트: 상태 동기화, 입력 잠금, 순서 바 문장, 손패 신호 전달, 적/아군 차례 표시, 드로우 흐림, 재생 도우미, 로그·배너.
# 실제 HUD 씬을 루트 창에 붙여 _ready 로 노드가 연결된 상태에서 검사한다.
extends TestCase

# 실제 HUD 씬.
const HudScene := preload("res://Scenes/battle_hud.tscn")
# 카드 데이터 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 적 데이터 스크립트.
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
# 배치 데이터 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
# 전투 구성 스크립트.
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 동기화로 손패·더미·SP 가 채워진다.
	_test_sync_builds_hand_and_piles()
	# 입력 잠금.
	_test_interactive_lock()
	# 순서 바 문장.
	_test_turn_bar_text()
	# 손패 신호가 HUD 신호로 전달된다.
	_test_hand_signals_are_relayed()
	# 적 차례: 손패 비움, 더미 흐림.
	_test_enemy_turn_clears_hand_and_dims_piles()
	# 아군 차례: 기록 시점 장수 표시.
	_test_ally_turn_shows_pile_snapshot()
	# 아군 차례 뒤 드로우: 흐림이 SP 기준.
	_test_ally_turn_then_draw_keeps_cards_affordable()
	# 재생용 도우미 함수들.
	_test_playback_helpers()
	# 로그와 배너.
	_test_log_and_banner()
	# 결과를 돌려준다.
	return results()


# HUD 씬을 만들어 루트 창에 붙인다 (_ready 가 돈다).
func _hud() -> BattleHud:
	# 씬 인스턴스.
	var hud: BattleHud = HudScene.instantiate()
	# 루트 창에 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	# 돌려준다.
	return hud


# id·방식·비용을 정한 카드 (사거리 2, 피해 6).
func _card(id: StringName, attack_type: CardData.AttackType, cost: int) -> CardData:
	# 빈 카드.
	var card: CardData = CardDataScript.new()
	# id.
	card.id = id
	# 이름.
	card.display_name = String(id)
	# 비용.
	card.sp_cost = cost
	# 공격 방식.
	card.attack_type = attack_type
	# 사거리.
	card.attack_range = 2
	# 피해.
	card.damage = 6
	# 돌려준다.
	return card


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	# 유닛 데이터.
	placement.unit_data = data
	# 칸.
	placement.cell = cell
	# 돌려준다.
	return placement


# 아군 a(속도 10, SP 3) 덱 strike(근접 1) / shot(원거리 1) / big(원거리 9) — 시작하면 3장 모두 손패, 덱 0. 적 e(속도 1).
func _started_state() -> BattleState:
	# 아군 데이터.
	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"a"
	# 이름.
	ally.display_name = "a"
	# 최대 체력.
	ally.max_hp = 30
	# 빠르게.
	ally.speed = 10
	# SP 3.
	ally.max_sp = 3
	# 세 장짜리 덱.
	var deck: Array[CardData] = [
		_card(&"strike", CardData.AttackType.MELEE, 1),
		_card(&"shot", CardData.AttackType.RANGED, 1),
		_card(&"big", CardData.AttackType.RANGED, 9),
	]
	# 덱을 넣는다.
	ally.deck = deck

	# 적 데이터.
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	# 이름.
	enemy.display_name = "e"
	# 최대 체력.
	enemy.max_hp = 20
	# 느리게.
	enemy.speed = 1

	# 전투 구성 (격자 기본 3×3).
	var encounter: EncounterData = EncounterScript.new()
	# 아군 배치.
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	# 적 배치.
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	# 아군 배치 넣기.
	encounter.ally_units = allies
	# 적 배치 넣기.
	encounter.enemy_units = enemies
	# 난수 생성기.
	var rng := RandomNumberGenerator.new()
	# 시드 고정.
	rng.seed = 3
	# 전투 상태.
	var state := BattleState.new(encounter, rng)
	# 시작 (아군 차례에서 멈춤).
	state.start_battle()
	# 돌려준다.
	return state


# 카드 화면 목록에서 이름으로 하나를 찾는다.
func _view_named(views: Array[CardView], display_name: String) -> CardView:
	# 화면마다.
	for view in views:
		# 이름이 같으면.
		if view.card.display_name == display_name:
			# 그 화면.
			return view
	# 못 찾음.
	return null


# 1 라운드, 둘 다 살아 있는 상태로 unit 의 차례 시작 이벤트를 손으로 만든다.
func _turn_event(state: BattleState, unit: Unit, turn_index: int) -> BattleEvent:
	# 차례 시작 이벤트.
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	# 주인공.
	event.unit = unit
	# 1 라운드.
	event.round_index = 1
	# 행동 순서.
	event.order = state.initiative
	# 생존 표시.
	var alive: Array[bool] = [true, true]
	# 넣는다.
	event.alive = alive
	# 순서 위치.
	event.turn_index = turn_index
	# 돌려준다.
	return event


# 시작한 전투로 동기화하면 카드 3 장, 근접 테두리, 비싼 카드 흐림, SP 글자, 더미 이름·장수, 버튼 활성이 맞는지.
func _test_sync_builds_hand_and_piles() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 시작한 전투.
	var state: BattleState = _started_state()
	# 동기화 (선택 없음).
	hud.sync_from_state(state, -1)
	# 입력 허용.
	hud.set_interactive(true)

	# 카드 화면들.
	var views: Array[CardView] = hud.hand_view().card_views()
	# 3 장.
	check_eq("one card view per card in hand", views.size(), 3)
	# strike 는 근접 테두리.
	check_eq("melee card border", _view_named(views, "strike").border_color(), CardView.MELEE_COLOR)
	# big 은 흐림.
	check_eq("unaffordable card dimmed", _view_named(views, "big").modulate, CardView.UNAFFORDABLE_MODULATE)
	# SP 글자.
	check_eq("sp panel text", hud.sp_text(), "SP\n●●●\n3 / 3")
	# 덱 더미 이름.
	check_eq("deck pile names the ally", hud.deck_pile().owner_text(), "a")
	# 덱 0.
	check_eq("deck pile count", hud.deck_pile().count_text(), "0")
	# 묘지 0.
	check_eq("discard pile count", hud.discard_pile().count_text(), "0")
	# 버튼 활성.
	check("end turn enabled", hud.end_turn_enabled())
	# 지운다.
	hud.free()


# 입력을 허용했다가 잠그면 손패·버튼이 잠기고 선택이 풀리는지.
func _test_interactive_lock() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 0 번 선택 상태로 동기화.
	hud.sync_from_state(_started_state(), 0)
	# 허용.
	hud.set_interactive(true)
	# 잠금.
	hud.set_interactive(false)
	# 손패 잠김.
	check("hand locked", not hud.hand_view().interactive)
	# 버튼 잠김.
	check("end turn locked", not hud.end_turn_enabled())
	# 선택 풀림.
	check_eq("lock clears the selection", hud.hand_view().selected_index(), -1)
	# 지운다.
	hud.free()


# 순서 바: 현재 유닛은 ▶ 표시, 이미 행동한 유닛은 회색, 쓰러진 유닛은 빠지는지.
func _test_turn_bar_text() -> void:
	# 시작한 전투.
	var state: BattleState = _started_state()
	# 행동 순서 [a, e].
	var order: Array[Unit] = state.initiative
	# 둘 다 살아 있음.
	var both_alive: Array[bool] = [true, true]
	# 적 쓰러짐.
	var enemy_dead: Array[bool] = [true, false]
	# a 차례.
	var current: String = BattleHud.turn_bar_text(1, order, both_alive, 0)
	# ▶a 가 있다.
	check("current unit marked", current.contains("▶a"))
	# e 차례 (a 는 행동함).
	var acted: String = BattleHud.turn_bar_text(1, order, both_alive, 1)
	# a 가 회색.
	check("acted unit greyed", acted.contains("[color=#%s]a[/color]" % BattleHud.ACTED_COLOR.to_html(false)))
	# 적이 쓰러진 a 차례.
	var dead: String = BattleHud.turn_bar_text(1, order, enemy_dead, 0)
	# ▶a 만 있고 화살표(→)가 없다.
	check("dead unit left out", dead.contains("▶a") and not dead.contains("→"))


# 손패가 낸 선택·놓기 신호가 HUD 신호로 그대로 나오는지.
func _test_hand_signals_are_relayed() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 선택 기록.
	var picked: Array = []
	# 놓기 기록.
	var dropped: Array = []
	# HUD 선택 신호를 기록한다.
	hud.card_selected.connect(func(index: int) -> void: picked.append(index))
	# HUD 놓기 신호를 기록한다.
	hud.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append([index, at]))
	# 손패가 선택 신호를 낸다.
	hud.hand_view().card_selected.emit(1)
	# 손패가 놓기 신호를 낸다.
	hud.hand_view().card_dropped.emit(0, Vector2(10, 20))
	# 선택 전달됨.
	check_eq("selection relayed", picked, [1])
	# 놓기 전달됨.
	check_eq("drop relayed", dropped, [[0, Vector2(10, 20)]])
	# 지운다.
	hud.free()


# 적 차례 시작을 보여 주면 손패가 비고, SP 가 숨고, 더미가 흐려지는지.
func _test_enemy_turn_clears_hand_and_dims_piles() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 시작한 전투.
	var state: BattleState = _started_state()
	# 먼저 아군 상태로 동기화.
	hud.sync_from_state(state, -1)
	# 적 차례 시작 이벤트를 보여 준다.
	hud.show_turn(_turn_event(state, state.living_units(Unit.Team.ENEMY)[0], 1))
	# 손패 0.
	check_eq("hand cleared on enemy turn", hud.hand_view().card_views().size(), 0)
	# SP 숨김.
	check_eq("sp hidden on enemy turn", hud.sp_text(), "")
	# 더미 흐림.
	check("piles dimmed on enemy turn", hud.deck_pile().is_dimmed())
	# 지운다.
	hud.free()


# 아군 차례 시작 이벤트의 기록 장수(덱 5, 묘지 2)가 실제 상태와 상관없이 더미에 표시되는지.
func _test_ally_turn_shows_pile_snapshot() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 시작한 전투.
	var state: BattleState = _started_state()
	# 아군 차례 이벤트.
	var event: BattleEvent = _turn_event(state, state.living_units(Unit.Team.ALLY)[0], 0)
	# 기록 덱 5.
	event.deck_count = 5
	# 기록 묘지 2.
	event.discard_count = 2
	# 보여 준다.
	hud.show_turn(event)
	# 덱 더미 이름.
	check_eq("deck owner is the acting ally", hud.deck_pile().owner_text(), "a")
	# 덱 5.
	check_eq("deck count from snapshot", hud.deck_pile().count_text(), "5")
	# 묘지 2.
	check_eq("discard count from snapshot", hud.discard_pile().count_text(), "2")
	# 더미 또렷함.
	check("piles lit on ally turn", not hud.deck_pile().is_dimmed())
	# 지운다.
	hud.free()


# 아군 차례 시작 직후 드로우한 카드의 흐림이 현재 SP(3) 기준인지: strike 는 또렷, big 은 흐림.
func _test_ally_turn_then_draw_keeps_cards_affordable() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 시작한 전투.
	var state: BattleState = _started_state()
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 아군 차례 시작을 보여 준다.
	hud.show_turn(_turn_event(state, ally, 0))
	# SP 글자.
	check_eq("sp shown at turn start", hud.sp_text(), "SP\n●●●\n3 / 3")

	# 손패의 카드마다 드로우 이벤트를 만들어 보여 준다.
	for card in ally.hand:
		# 드로우 이벤트.
		var drawn := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
		# 주인공.
		drawn.unit = ally
		# 카드.
		drawn.card = card
		# 드로우 연출.
		hud.draw_card(drawn)
	# 카드 화면들.
	var views: Array[CardView] = hud.hand_view().card_views()
	# strike 또렷.
	check_eq("affordable drawn card not dimmed", _view_named(views, "strike").modulate, Color.WHITE)
	# big 흐림.
	check_eq("unaffordable drawn card dimmed", _view_named(views, "big").modulate, CardView.UNAFFORDABLE_MODULATE)
	# 지운다.
	hud.free()


# 재생 도우미 draw_card / remove_played_card / discard_hand / reshuffle 가 손패 장수와 더미 숫자를 바꾸는지.
func _test_playback_helpers() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 시작한 전투 (손패 3).
	var state: BattleState = _started_state()
	# 아군.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 동기화.
	hud.sync_from_state(state, -1)

	# 드로우 이벤트.
	var drawn := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
	# 주인공.
	drawn.unit = ally
	# 카드.
	drawn.card = ally.hand[0]
	# 덱 1.
	drawn.deck_count = 1
	# 묘지 0.
	drawn.discard_count = 0
	# 드로우.
	hud.draw_card(drawn)
	# 손패 4.
	check_eq("drawn card joins the hand", hud.hand_view().card_views().size(), 4)
	# 덱 1.
	check_eq("deck count after draw", hud.deck_pile().count_text(), "1")

	# 카드 사용 이벤트.
	var played := BattleEvent.new(BattleEvent.Kind.CARD_PLAYED)
	# 주인공.
	played.unit = ally
	# 카드.
	played.card = ally.hand[0]
	# 덱 1.
	played.deck_count = 1
	# 묘지 1.
	played.discard_count = 1
	# 0 번이 사용될 카드.
	hud.set_pending_play(0)
	# 사용 반영.
	hud.remove_played_card(played)
	# 손패 3.
	check_eq("played card leaves the hand", hud.hand_view().card_views().size(), 3)
	# 묘지 1.
	check_eq("discard count after play", hud.discard_pile().count_text(), "1")

	# 손패 버리기 이벤트.
	var discarded := BattleEvent.new(BattleEvent.Kind.HAND_DISCARDED)
	# 주인공.
	discarded.unit = ally
	# 묘지 4.
	discarded.discard_count = 4
	# 덱 1.
	discarded.deck_count = 1
	# 버리기.
	hud.discard_hand(discarded)
	# 손패 0.
	check_eq("hand empty after discard", hud.hand_view().card_views().size(), 0)
	# 묘지 4.
	check_eq("discard count after discard", hud.discard_pile().count_text(), "4")

	# 리셔플 이벤트.
	var reshuffled := BattleEvent.new(BattleEvent.Kind.DECK_RESHUFFLED)
	# 주인공.
	reshuffled.unit = ally
	# 4 장 섞음.
	reshuffled.amount = 4
	# 덱 5.
	reshuffled.deck_count = 5
	# 묘지 0.
	reshuffled.discard_count = 0
	# 리셔플.
	hud.reshuffle(reshuffled)
	# 덱 5.
	check_eq("deck refilled", hud.deck_pile().count_text(), "5")
	# 묘지 0.
	check_eq("discard emptied", hud.discard_pile().count_text(), "0")
	# 지운다.
	hud.free()


# 로그에 쓴 줄이 남고, 패배 배너가 보이며 문구가 "패배..." 인지.
func _test_log_and_banner() -> void:
	# HUD.
	var hud: BattleHud = _hud()
	# 로그 한 줄.
	hud.append_log("hello")
	# 남아 있다.
	check("log keeps lines", hud.log_text().contains("hello"))
	# 패배 배너.
	hud.show_banner(false)
	# 보인다.
	check("banner shown", hud.banner_visible())
	# 문구.
	check_eq("defeat banner text", hud.banner_text(), "패배...")
	# 지운다.
	hud.free()
