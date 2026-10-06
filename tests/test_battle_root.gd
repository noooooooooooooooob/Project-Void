# BattleRoot(전투 씬 루트) 테스트: 전투 종료 신호는 마지막 연출(처치·승패 배너) 재생이 끝난 뒤에 나가야 한다.
# 맵(GameRoot)은 이 신호를 받자마자 전투 씬을 지우므로, 먼저 나가면 결정타 연출이 재생되지 않는다.
extends TestCase

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
	# 종료 신호는 재생 뒤.
	_test_finish_signal_waits_for_playback()
	# 결과를 돌려준다.
	return results()


# 데이터와 칸으로 배치 한 줄을 만든다.
func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	# 배치 리소스.
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 a 가 피해 50 원거리 카드 한 장으로 HP 20 적 e 를 한 방에 쓰러뜨리는 전투.
func _encounter() -> EncounterData:
	# 한 방 카드.
	var card: CardData = CardDataScript.new()
	card.id = &"zap"
	card.display_name = "zap"
	card.sp_cost = 1
	card.attack_type = CardData.AttackType.RANGED
	card.attack_range = 9
	card.damage = 50
	# 아군.
	var ally: AllyData = AllyDataScript.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = 3
	var deck: Array[CardData] = [card]
	ally.deck = deck
	# 적.
	var enemy: EnemyData = EnemyDataScript.new()
	enemy.id = &"e"
	enemy.display_name = "e"
	enemy.max_hp = 20
	enemy.speed = 1
	enemy.move_chance = 0.0
	# 구성.
	var encounter: EncounterData = EncounterScript.new()
	var allies: Array[UnitPlacement] = [_placement(ally, Vector2i(0, 1))]
	var enemies: Array[UnitPlacement] = [_placement(enemy, Vector2i(0, 1))]
	encounter.ally_units = allies
	encounter.enemy_units = enemies
	return encounter


# 결정타를 재생할 때 battle_finished 가 나가는 순간 이미 승리 배너가 떠 있는지 (= 재생이 끝난 뒤인지).
func _test_finish_signal_waits_for_playback() -> void:
	# 씬을 만든다.
	var battle: BattleRoot = BattleScene.instantiate()
	battle.encounter = _encounter()
	# 연출 없이 즉시 재생 (트리에 붙기 전에 켜야 시작 재생도 즉시 끝난다).
	(battle.get_node("Playback") as BattlePlayback).instant = true
	# 신호가 나간 순간의 배너 상태 (람다에서 바꾸려고 배열에 담는다): [나간 횟수, 그때 배너가 보였는지, 승리 여부].
	var seen: Array = [0, false, false]
	battle.battle_finished.connect(func(ally_won: bool) -> void:
		seen[0] += 1
		seen[1] = battle.get_node("HudLayer/Hud").banner_visible()
		seen[2] = ally_won)
	# 트리에 붙여 _ready 로 전투를 시작한다.
	(Engine.get_main_loop() as SceneTree).root.add_child(battle)
	# 적.
	var foe: Unit = battle._state.living_units(Unit.Team.ENEMY)[0]
	# 결정타.
	battle._run(func() -> void: battle._state.play_card(0, foe.team, foe.cell))
	# 한 번 나갔다.
	check_eq("battle_finished emitted once", seen[0], 1)
	# 승리.
	check("battle_finished reports the win", seen[2])
	# 나가는 순간 이미 결정타 재생(배너까지)이 끝나 있었다.
	check("battle_finished waits for the final playback", seen[1])
	# 정리.
	battle.free()
