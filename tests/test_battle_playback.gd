extends TestCase

const HudScene := preload("res://Scenes/battle_hud.tscn")
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
const EnemyDataScript := preload("res://Scripts/combat/data/enemy_data.gd")
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")
const EncounterScript := preload("res://Scripts/combat/data/encounter_data.gd")


func run() -> Array[Dictionary]:
	_test_turn_start_highlights_and_logs()
	_test_kill_plays_to_banner()
	_test_heal_and_block_update_view()
	_test_turn_start_draws_into_hand()
	_test_end_turn_discards_then_reshuffles_and_draws()
	return results()


func _placement(data: UnitData, cell: Vector2i) -> UnitPlacement:
	var placement: UnitPlacement = PlacementScript.new()
	placement.unit_data = data
	placement.cell = cell
	return placement


# 아군 a(속도 10) 가 zap(원거리, 피해 50) 한 장, 적 e(속도 1, HP 20) 1기.
func _rig() -> Dictionary:
	var card: CardData = CardDataScript.new()
	card.id = &"zap"
	card.display_name = "zap"
	card.sp_cost = 1
	card.attack_type = CardData.AttackType.RANGED
	card.attack_range = 9
	card.damage = 50

	var ally: AllyData = AllyDataScript.new()
	ally.id = &"a"
	ally.display_name = "a"
	ally.max_hp = 30
	ally.speed = 10
	ally.max_sp = 3
	var deck: Array[CardData] = [card]
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
	rng.seed = 8
	var state := BattleState.new(encounter, rng)

	var recorder := BattleEventRecorder.new(state)
	var board := Board3D.new()
	board.build(state, ImageTexture.create_from_image(Image.create(10, 20, false, Image.FORMAT_RGBA8)))
	var hud: BattleHud = HudScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var playback := BattlePlayback.new()
	playback.board = board
	playback.hud = hud
	playback.instant = true
	return {"state": state, "recorder": recorder, "board": board, "hud": hud, "playback": playback}


func _free(rig: Dictionary) -> void:
	(rig["board"] as Board3D).free()
	(rig["hud"] as BattleHud).free()
	(rig["playback"] as BattlePlayback).free()


func _test_turn_start_highlights_and_logs() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var board: Board3D = rig["board"]
	var hud: BattleHud = rig["hud"]
	var playback: BattlePlayback = rig["playback"]
	var finished_count: Array = [0]
	playback.finished.connect(func() -> void: finished_count[0] += 1)

	state.start_battle()
	playback.play(recorder.take_events())
	check_eq("current tile highlighted", board.tile_state(Unit.Team.ALLY, Vector2i(0, 1)), Board3D.TileState.CURRENT)
	check("turn logged", hud.log_text().contains("― a 차례"))
	check_eq("finished once, synchronously", finished_count[0], 1)
	_free(rig)


func _test_kill_plays_to_banner() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var board: Board3D = rig["board"]
	var hud: BattleHud = rig["hud"]
	var playback: BattlePlayback = rig["playback"]

	state.start_battle()
	playback.play(recorder.take_events())
	board.sync_from_state(state)
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]

	state.play_card(0, foe)
	playback.play(recorder.take_events())
	check_eq("hp shown at zero", board.view_for(foe).stat_label.text, "0/20")
	check("dead view hidden", not board.view_for(foe).visible)
	check_eq("dead tile empty", board.tile_state(Unit.Team.ENEMY, Vector2i(0, 1)), Board3D.TileState.EMPTY)
	check("card log from the rules", hud.log_text().contains("a → e (zap)"))
	check("damage log", hud.log_text().contains("e 에게 50 피해"))
	check("victory banner", hud.banner_visible())
	check_eq("played card left the hand", hud.hand_view().card_views().size(), 0)
	_free(rig)


func _test_heal_and_block_update_view() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var board: Board3D = rig["board"]
	var playback: BattlePlayback = rig["playback"]
	var foe: Unit = state.living_units(Unit.Team.ENEMY)[0]
	var view: UnitView = board.view_for(foe)

	var healed := BattleEvent.new(BattleEvent.Kind.HEALED)
	healed.unit = foe
	healed.amount = 3
	healed.hp = 12
	var heal_events: Array[BattleEvent] = [healed]
	playback.play(heal_events)
	check_eq("heal updates hp", view.stat_label.text, "12/20")

	var guarded := BattleEvent.new(BattleEvent.Kind.BLOCK_GAINED)
	guarded.unit = foe
	guarded.amount = 5
	guarded.block = 5
	var block_events: Array[BattleEvent] = [guarded]
	playback.play(block_events)
	check_eq("block keeps the shown hp", view.stat_label.text, "12/20  방5")
	_free(rig)


func _test_turn_start_draws_into_hand() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var hud: BattleHud = rig["hud"]
	var playback: BattlePlayback = rig["playback"]

	state.start_battle()
	playback.play(recorder.take_events())
	check_eq("drawn card is in the hand", hud.hand_view().card_views().size(), 1)
	check_eq("deck pile emptied by the draw", hud.deck_pile().count_text(), "0")
	check_eq("deck pile names the ally", hud.deck_pile().owner_text(), "a")
	_free(rig)


func _test_end_turn_discards_then_reshuffles_and_draws() -> void:
	var rig: Dictionary = _rig()
	var state: BattleState = rig["state"]
	var recorder: BattleEventRecorder = rig["recorder"]
	var hud: BattleHud = rig["hud"]
	var playback: BattlePlayback = rig["playback"]

	state.start_battle()
	playback.play(recorder.take_events())
	state.end_turn()
	var events: Array[BattleEvent] = recorder.take_events()

	var discard_only: Array[BattleEvent] = [events[0]]
	playback.play(discard_only)
	check_eq("hand discarded", hud.hand_view().card_views().size(), 0)
	check_eq("discard pile holds the card", hud.discard_pile().count_text(), "1")

	playback.play(events.slice(1))
	check_eq("card drawn again after the reshuffle", hud.hand_view().card_views().size(), 1)
	check_eq("discard pile emptied by the reshuffle", hud.discard_pile().count_text(), "0")
	_free(rig)
