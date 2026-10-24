# BattleRoot(전투 씬 루트) 테스트: 전투 종료 신호는 마지막 연출(처치·승패 배너) 재생이 끝난 뒤에 나가야 한다.
# 맵(GameRoot)은 이 신호를 받자마자 전투 씬을 지우므로, 먼저 나가면 결정타 연출이 재생되지 않는다.
extends TestCase

# 픽스처.
const Fixtures := preload("res://tests/fixtures.gd")

# 실제 전투 씬.
const BattleScene := preload("res://Scenes/battle_3d.tscn")
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
	_test_finish_signal_waits_for_playback()
	# Esc 메뉴와 도망가기.
	_test_escape_toggles_the_flee_menu()
	_test_fleeing_emits_battle_fled_only()
	_test_escape_is_ignored_after_the_battle_ends()
	# 근접 카드는 놓기만 하면 자동으로 쓰인다.
	_test_melee_card_drop_plays_automatically()
	# 아군 카드는 아군 칸을 겨냥한다.
	_test_ally_card_targets_ally_cell()
	# 실제 전투 구성에서 같은 행에 적이 없으면 근접 카드가 흐리다.
	_test_melee_cards_dim_in_skirmish_when_row_empty()
	# 자동 카드를 손패 위로 되돌려 놓으면 취소된다.
	_test_auto_card_dropped_on_hand_is_cancelled()
	# 조준 카드로 후보가 아닌 유닛에 커서를 올리면 무효 표시.
	_test_hovering_an_invalid_unit_shows_invalid()
	return results()


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 a 가 피해 50 원거리 카드 한 장으로 HP 20 적 e 를 한 방에 쓰러뜨리는 전투.
func _encounter(deck_card: CardData = null) -> EncounterData:
	var card: CardData = CardDataScript.new()
	# id.
	card.id = &"zap"
	card.display_name = "zap"
	# SP 1.
	card.sp_cost = 1
	# 원거리 (막힘 무시).
	card.attack_type = CardData.AttackType.RANGED
	# 적 HP 보다 큰 피해.
	card.effects = [Fixtures.effect(CardEffect.Kind.DAMAGE, 500)]
	var ally: AllyData = AllyDataScript.new()
	# id.
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	# 적보다 빨라서 먼저 행동한다.
	ally.speed = 10
	# SP.
	ally.max_sp = 3
	# 덱은 한 방 카드 한 장 (따로 준 카드가 있으면 그 카드).
	var deck: Array[CardData] = [card if deck_card == null else deck_card]
	ally.deck = deck
	var enemy: EnemyData = EnemyDataScript.new()
	# id.
	enemy.id = &"e"
	enemy.display_name = "e"
	# 체력 20.
	enemy.max_hp = 20
	enemy.speed = 1
	enemy.move_chance = 0.0
	var encounter: EncounterData = EncounterScript.new()
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	return encounter


# 결정타를 재생할 때 battle_finished 가 나가는 순간 이미 승리 배너가 떠 있는지 (= 재생이 끝난 뒤인지).
func _test_finish_signal_waits_for_playback() -> void:
	var battle: BattleRoot = BattleScene.instantiate()
	battle.encounter = _encounter()
	# 연출 없이 즉시 재생 (트리에 붙기 전에 켜야 시작 재생도 즉시 끝난다).
	(battle.get_node("Playback") as BattlePlayback).instant = true
	# 신호가 나간 순간의 배너 상태 (람다에서 바꾸려고 배열에 담는다): [나간 횟수, 그때 배너가 보였는지, 승리 여부].
	var seen: Array = [0, false, false]
	# 신호를 받으면 그 순간의 상태를 기록한다.
	battle.battle_finished.connect(func(ally_won: bool) -> void:
		seen[0] += 1
		seen[1] = battle.get_node("HudLayer/Hud").banner_visible()
		seen[2] = ally_won)
	# 트리에 붙여 _ready 로 전투를 시작한다.
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	var foe: Unit = battle._state.living_units(Unit.Team.ENEMY)[0]
	battle._run(func() -> void: battle._state.play_card(0, foe))
	check_eq("battle_finished emitted once", seen[0], 1)
	check("battle_finished reports the win", seen[2])
	# 나가는 순간 이미 결정타 재생(배너까지)이 끝나 있었다.
	check("battle_finished waits for the final playback", seen[1])
	battle.free()


# Esc 입력 이벤트.
func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	# Esc 에 묶인 동작.
	event.action = &"ui_cancel"
	event.pressed = true
	return event


# 연출 없이 시작한 전투를 트리에 붙여 돌려준다.
func _started_battle() -> BattleRoot:
	var battle: BattleRoot = BattleScene.instantiate()
	battle.encounter = _encounter()
	(battle.get_node("Playback") as BattlePlayback).instant = true
	# 트리에 붙여 전투를 시작한다.
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	return battle


# Esc 를 누르면 메뉴가 열리고, 다시 누르거나 계속하기를 누르면 닫힌다.
func _test_escape_toggles_the_flee_menu() -> void:
	var battle: BattleRoot = _started_battle()
	check("the flee menu starts closed", not battle._flee_menu.is_open())
	# Esc.
	battle._unhandled_input(_escape_event())
	check("Esc opens the flee menu", battle._flee_menu.is_open())
	# 다시 Esc.
	battle._unhandled_input(_escape_event())
	check("Esc again closes it", not battle._flee_menu.is_open())
	battle._unhandled_input(_escape_event())
	battle._flee_menu.resume_button().pressed.emit()
	check("the resume button closes it", not battle._flee_menu.is_open())
	battle.free()


# 도망가기는 battle_fled 만 내고 battle_finished(승패) 는 내지 않는다. 메뉴는 닫힌다.
func _test_fleeing_emits_battle_fled_only() -> void:
	var battle: BattleRoot = _started_battle()
	# [도망 신호 횟수, 종료 신호 횟수].
	var counts: Array[int] = [0, 0]
	battle.battle_fled.connect(func() -> void: counts[0] += 1)
	battle.battle_finished.connect(func(_ally_won: bool) -> void: counts[1] += 1)
	battle._unhandled_input(_escape_event())
	battle._flee_menu.flee_button().pressed.emit()
	check_eq("battle_fled is emitted once", counts[0], 1)
	check_eq("battle_finished is not emitted", counts[1], 0)
	check("the menu closes after fleeing", not battle._flee_menu.is_open())
	battle.free()


# 전투가 끝난 뒤에는 Esc 가 메뉴를 열지 않는다.
func _test_escape_is_ignored_after_the_battle_ends() -> void:
	var battle: BattleRoot = _started_battle()
	var foe: Unit = battle._state.living_units(Unit.Team.ENEMY)[0]
	battle._run(func() -> void: battle._state.play_card(0, foe))
	check("the battle is over", battle._state.finished)
	# Esc.
	battle._unhandled_input(_escape_event())
	check("Esc does not open the menu after the battle", not battle._flee_menu.is_open())
	battle.free()


# 덱이 card 한 장인 전투 씬을 연출 없이 띄운다 (첫 아군 차례에서 멈춘 상태).
func _battle(card: CardData) -> BattleRoot:
	var battle: BattleRoot = BattleScene.instantiate()
	battle.encounter = _encounter(card)
	(battle.get_node("Playback") as BattlePlayback).instant = true
	# 트리에 붙여 전투를 시작한다.
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	return battle


# 근접 카드는 놓기만 하면(위치와 상관없이) 같은 행 맨 앞 적에게 쓰인다.
func _test_melee_card_drop_plays_automatically() -> void:
	# 근접 피해 100% (공격 10 → 10).
	var battle: BattleRoot = _battle(Fixtures.damage_card(&"auto", CardData.AttackType.MELEE, 100))
	# 적 (아군과 같은 행 1).
	var foe: Unit = battle._state.living_units(Unit.Team.ENEMY)[0]
	battle._on_card_dropped(0, Vector2(5, 5))
	# 20 - 10 = 10.
	check_eq("melee auto hit the front enemy", foe.hp, 10)
	battle.free()


# 아군 회복 카드는 아군 칸을 클릭해 쓴다.
func _test_ally_card_targets_ally_cell() -> void:
	# 아군 회복 30% (공격 10 → 3).
	var effects: Array[CardEffect] = [Fixtures.effect(CardEffect.Kind.HEAL, 30)]
	var battle: BattleRoot = _battle(Fixtures.card(&"heal", CardData.AttackType.ALLY, effects))
	var actor: Unit = battle._state.current_unit()
	# 체력을 5 깎아 둔다.
	actor.hp -= 5
	# 고른 뒤 자기 칸을 클릭한다.
	battle._on_card_selected(0)
	battle._on_cell_clicked(actor.team, actor.cell)
	# 30 - 5 + 3 = 28.
	check_eq("ally heal applied", actor.hp, 28)
	battle.free()


# 실제 skirmish 전투에서 차례 아군의 행에 적이 없으면 손패의 근접 카드가 흐리다 (게임에서 확인된 문제의 재현).
func _test_melee_cards_dim_in_skirmish_when_row_empty() -> void:
	var battle: BattleRoot = BattleScene.instantiate()
	battle.encounter = load("res://Resources/encounters/skirmish.tres")
	(battle.get_node("Playback") as BattlePlayback).instant = true
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	var actor: Unit = battle._state.current_unit()
	# 같은 행에 적이 없는 상황인지 (아니면 이 테스트는 의미가 없다).
	var row_empty: bool = battle._state.resolver.melee_anchor(actor, battle._state.units) == null
	var views: Array[CardView] = battle._hud.hand_view().card_views()
	# 근접 카드가 하나라도 또렷하면 실패.
	var melee_bright: bool = false
	for view in views:
		if view.card.attack_type == CardData.AttackType.MELEE and view.modulate == Color.WHITE:
			melee_bright = true
	check("row empty for the first actor", row_empty)
	check("melee cards dimmed when the row is empty", not melee_bright)
	battle.free()


# 근접 카드를 손패 영역(화면 아래쪽)에 되돌려 놓으면 쓰이지 않고 선택이 풀린다.
func _test_auto_card_dropped_on_hand_is_cancelled() -> void:
	# 근접 피해 100%.
	var battle: BattleRoot = _battle(Fixtures.damage_card(&"auto", CardData.AttackType.MELEE, 100))
	var foe: Unit = battle._state.living_units(Unit.Team.ENEMY)[0]
	battle._on_card_dropped(0, Vector2(5, 100000))
	check_eq("dropping on the hand does not play", foe.hp, 20)
	check_eq("dropping on the hand clears the selection", battle._selected_card, -1)
	battle.free()


# 원거리 카드를 고르고 아군 유닛(후보 아님)에 커서를 올리면 그 칸이 무효(주황)로 표시된다.
func _test_hovering_an_invalid_unit_shows_invalid() -> void:
	var battle: BattleRoot = _battle(Fixtures.damage_card(&"shot", CardData.AttackType.RANGED, 50))
	var actor: Unit = battle._state.current_unit()
	battle._on_card_selected(0)
	battle._on_cell_hovered(actor.team, actor.cell)
	check_eq("invalid hover is marked", battle._board.tile_state(actor.team, actor.cell), Board3D.TileState.SHAPE_OUT)
	battle.free()
