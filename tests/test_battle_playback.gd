# BattlePlayback(이벤트 재생) 테스트. instant 모드로 연출 없이 재생해 화면 표시 결과만 확인한다.
# 규칙 → 기록기 → 재생 → 보드·HUD 로 이어지는 실제 연결을 그대로 만들어 쓴다.
extends TestCase

# 실제 HUD 씬 (노드 구성이 씬 파일에 있다).
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
	# 차례 시작: 강조와 로그.
	_test_turn_start_highlights_and_logs()
	# 처치까지 재생하면 승리 배너.
	_test_kill_plays_to_banner()
	# 회복·방어도 표시.
	_test_heal_and_block_update_view()
	# 차례 시작 드로우가 손패에 들어온다.
	_test_turn_start_draws_into_hand()
	# 차례 종료: 버리기 → 리셔플 → 드로우.
	_test_end_turn_discards_then_reshuffles_and_draws()
	# 아군 이동 이벤트 재생.
	_test_move_event_moves_the_view()
	# 결과를 돌려준다.
	return results()


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


# 아군 a(속도 10) 가 zap(원거리, 피해 50) 한 장, 적 e(속도 1, HP 20) 1기.
# 전투 상태·기록기·보드·HUD·재생기를 만들어 사전으로 돌려준다.
func _rig() -> Dictionary:
	# zap 카드.
	var card: CardData = CardDataScript.new()
	# id.
	card.id = &"zap"
	# 이름.
	card.display_name = "zap"
	# 비용 1.
	card.sp_cost = 1
	# 원거리.
	card.attack_type = CardData.AttackType.RANGED
	# 사거리 9.
	card.attack_range = 9
	# 한 방에 쓰러뜨리는 피해 50.
	card.damage = 50

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
	# SP.
	ally.max_sp = 3
	# 카드 한 장짜리 덱.
	var deck: Array[CardData] = [card]
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
	# 무작위 이동을 끈다 (재생 결과를 정확히 확인하기 위해).
	enemy.move_chance = 0.0

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
	rng.seed = 8
	# 전투 상태.
	var state := BattleState.new(encounter, rng)

	# 신호 기록기 (전투 시작 전에 연결).
	var recorder := BattleEventRecorder.new(state)
	# 보드.
	var board := Board3D.new()
	# 임시 그림으로 보드를 만든다.
	board.build(state, ImageTexture.create_from_image(Image.create(10, 20, false, Image.FORMAT_RGBA8)))
	# HUD 씬 인스턴스.
	var hud: BattleHud = HudScene.instantiate()
	# _ready 가 돌아 %노드들이 연결되도록 루트 창에 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	# 재생기.
	var playback := BattlePlayback.new()
	# 보드 연결.
	playback.board = board
	# HUD 연결.
	playback.hud = hud
	# 연출 없이 즉시 재생 (play 가 동기로 끝난다).
	playback.instant = true
	# 필요한 객체들을 묶어 돌려준다.
	return {"state": state, "recorder": recorder, "board": board, "hud": hud, "playback": playback}


# _rig 가 만든 노드들을 지운다.
func _free(rig: Dictionary) -> void:
	# 보드.
	(rig["board"] as Board3D).free()
	# HUD.
	(rig["hud"] as BattleHud).free()
	# 재생기.
	(rig["playback"] as BattlePlayback).free()


# 전투 시작 이벤트를 재생하면 아군 칸이 강조되고, 로그에 차례 줄이 생기고, finished 가 한 번 즉시 나오는지.
func _test_turn_start_highlights_and_logs() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 기록기.
	var recorder: BattleEventRecorder = rig["recorder"]
	# 보드.
	var board: Board3D = rig["board"]
	# HUD.
	var hud: BattleHud = rig["hud"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]
	# finished 횟수 (람다에서 바꾸려고 배열에 담는다).
	var finished_count: Array = [0]
	# finished 가 나올 때마다 센다.
	playback.finished.connect(func() -> void: finished_count[0] += 1)

	# 전투 시작.
	state.start_battle()
	# 쌓인 이벤트 재생.
	playback.play(recorder.take_events())
	# 아군 칸 강조.
	check_eq("current tile highlighted", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.CURRENT)
	# 차례 로그.
	check("turn logged", hud.log_text().contains("― a 차례"))
	# 동기로 한 번 끝났다.
	check_eq("finished once, synchronously", finished_count[0], 1)
	# 정리.
	_free(rig)


# 피해 50 카드로 적을 쓰러뜨리는 이벤트를 재생하면 체력 0 표시, 숨김, 빈 칸, 로그, 승리 배너, 손패 비움이 되는지.
func _test_kill_plays_to_banner() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 기록기.
	var recorder: BattleEventRecorder = rig["recorder"]
	# 보드.
	var board: Board3D = rig["board"]
	# HUD.
	var hud: BattleHud = rig["hud"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]

	# 시작.
	state.start_battle()
	# 시작 이벤트 재생.
	playback.play(recorder.take_events())
	# 보드 동기화.
	board.sync_from_state(state)
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	# 카드를 쓴다 (적 처치, 전투 종료).
	state.play_card(0, foe)
	# 그 이벤트들을 재생한다.
	playback.play(recorder.take_events())
	# 체력 글자 0/20.
	check_eq("hp shown at zero", board.view_for(foe).stat_label.text, "0/20")
	# 적 화면 숨김.
	check("dead view hidden", not board.view_for(foe).visible)
	# 적 칸 빈 칸.
	check_eq("dead tile empty", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 1)), Board3D.TileState.EMPTY)
	# 규칙이 남긴 카드 사용 로그.
	check("card log from the rules", hud.log_text().contains("a → e (zap)"))
	# 재생기가 남긴 피해 로그.
	check("damage log", hud.log_text().contains("e 에게 50 피해"))
	# 승리 배너.
	check("victory banner", hud.banner_visible())
	# 쓴 카드는 손패에서 빠졌다.
	check_eq("played card left the hand", hud.hand_view().card_views().size(), 0)
	# 정리.
	_free(rig)


# 직접 만든 회복·방어도 이벤트를 재생하면 체력 글자와 방어도 글자가 갱신되는지.
func _test_heal_and_block_update_view() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 보드.
	var board: Board3D = rig["board"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]
	# 적 유닛.
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	# 적 화면.
	var view: UnitView = board.view_for(foe)

	# 회복 이벤트를 손으로 만든다.
	var healed := BattleEvent.new(BattleEvent.Kind.HEALED)
	# 대상.
	healed.unit = foe
	# 회복량.
	healed.amount = 3
	# 회복 후 체력.
	healed.hp = 12
	# 이벤트 배열.
	var heal_events: Array[BattleEvent] = [healed]
	# 재생.
	playback.play(heal_events)
	# 체력 12/20.
	check_eq("heal updates hp", view.stat_label.text, "12/20")

	# 방어도 이벤트를 손으로 만든다.
	var guarded := BattleEvent.new(BattleEvent.Kind.BLOCK_GAINED)
	# 대상.
	guarded.unit = foe
	# 얻은 양.
	guarded.amount = 5
	# 얻은 뒤 방어도.
	guarded.block = 5
	# 이벤트 배열.
	var block_events: Array[BattleEvent] = [guarded]
	# 재생.
	playback.play(block_events)
	# 체력은 유지하고 방어도가 붙는다.
	check_eq("block keeps the shown hp", view.stat_label.text, "12/20  방5")
	# 정리.
	_free(rig)


# 전투 시작 이벤트(드로우 포함)를 재생하면 손패 1 장, 덱 더미 0, 더미 이름 a 가 되는지.
func _test_turn_start_draws_into_hand() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 기록기.
	var recorder: BattleEventRecorder = rig["recorder"]
	# HUD.
	var hud: BattleHud = rig["hud"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]

	# 시작.
	state.start_battle()
	# 재생.
	playback.play(recorder.take_events())
	# 손패 1 장 (덱이 1 장뿐).
	check_eq("drawn card is in the hand", hud.hand_view().card_views().size(), 1)
	# 덱 더미 0.
	check_eq("deck pile emptied by the draw", hud.deck_pile().count_text(), "0")
	# 더미 이름.
	check_eq("deck pile names the ally", hud.deck_pile().owner_text(), "a")
	# 정리.
	_free(rig)


# 차례 종료 이벤트를 두 번에 나눠 재생: 먼저 버리기만 → 손패 0·묘지 1, 나머지(리셔플·드로우) → 손패 1·묘지 0.
func _test_end_turn_discards_then_reshuffles_and_draws() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 기록기.
	var recorder: BattleEventRecorder = rig["recorder"]
	# HUD.
	var hud: BattleHud = rig["hud"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]

	# 시작.
	state.start_battle()
	# 시작 이벤트 재생.
	playback.play(recorder.take_events())
	# 차례 종료 (버리기 → 적 차례 → 리셔플·드로우).
	state.end_turn()
	# 그 이벤트들을 꺼낸다.
	var events: Array[BattleEvent] = recorder.take_events()

	# 첫 이벤트(손패 버리기)만.
	var discard_only: Array[BattleEvent] = [events[0]]
	# 재생.
	playback.play(discard_only)
	# 손패 0.
	check_eq("hand discarded", hud.hand_view().card_views().size(), 0)
	# 묘지 1.
	check_eq("discard pile holds the card", hud.discard_pile().count_text(), "1")

	# 나머지 이벤트 재생.
	playback.play(events.slice(1))
	# 다시 손패 1.
	check_eq("card drawn again after the reshuffle", hud.hand_view().card_views().size(), 1)
	# 묘지 0.
	check_eq("discard pile emptied by the reshuffle", hud.discard_pile().count_text(), "0")
	# 정리.
	_free(rig)


# 아군이 (0,1)→(1,1) 로 이동한 이벤트를 재생하면 화면 위치·강조 타일·SP 패널·로그가 바뀌는지.
func _test_move_event_moves_the_view() -> void:
	# 준비물.
	var rig: Dictionary = _rig()
	# 전투 상태.
	var state: BattleState = rig["state"]
	# 기록기.
	var recorder: BattleEventRecorder = rig["recorder"]
	# 보드.
	var board: Board3D = rig["board"]
	# HUD.
	var hud: BattleHud = rig["hud"]
	# 재생기.
	var playback: BattlePlayback = rig["playback"]

	# 시작.
	state.start_battle()
	# 시작 이벤트 재생.
	playback.play(recorder.take_events())
	# 아군 유닛.
	var ally: Unit = state.living_units(Unit.Team.ALLY)[0]
	# 한 칸 뒤로 이동.
	state.move_unit(Vector2i(1, 1))
	# 이동 이벤트 재생.
	playback.play(recorder.take_events())
	# 화면 위치.
	check("view moved to the new cell", board.view_for(ally).position.is_equal_approx(board.layout.cell_position(Unit.Team.ALLY, Vector2i(1, 1))))
	# 새 칸 강조.
	check_eq("new cell highlighted", board.tile_state(Unit.Team.ALLY, Vector2i(1, 1)), Board3D.TileState.CURRENT)
	# SP 2 표시.
	check_eq("sp panel shows the spent sp", hud.sp_text(), "SP\n●●○\n2 / 3")
	# 로그.
	check("move logged", hud.log_text().contains("a 이동"))
	# 정리.
	_free(rig)
