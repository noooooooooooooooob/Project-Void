class_name GameRoot
extends Node

const BattleScene: PackedScene = preload("res://Scenes/battle_3d.tscn")
const BOSS_CLEARED_TEXT: String = "챕터 클리어! 새 지도를 펼칩니다"
const DEFEATED_TEXT: String = "패배... 파티를 정비하고 다시 도전하세요"
const FLED_TEXT: String = "전투에서 도망쳤습니다"
## 시작할 때 가방에 넣어 주는 아이템 수.
const STARTING_ITEM_COUNT: int = 3

var run_state: MapRunState
var party: PartyState
var map_view: MapView
var party_view: PartyView
var _rng: RandomNumberGenerator
var _item_pool: Array[ItemData] = []
var _battle: BattleRoot


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	run_state = MapRunState.new(_rng)

	party = PartyState.new(EncounterGenerator.build_ally_roster(_rng))
	_item_pool = ItemPool.load_all()
	for i in STARTING_ITEM_COUNT:
		party.add_item(ItemPool.roll(_rng, _item_pool))

	map_view = MapView.new(run_state.graph)
	add_child(map_view)
	map_view.node_selected.connect(_on_node_selected)
	map_view.party_requested.connect(_on_party_requested)
	map_view.sync_from_state(run_state)

	# 지도 위에 겹쳐 그려지도록 지도보다 나중에 붙인다.
	party_view = PartyView.new()
	party_view.hide()
	add_child(party_view)
	party_view.bind(party)
	party_view.closed.connect(_on_party_closed)


func _on_node_selected(node_id: int) -> void:
	if _battle != null or not run_state.is_selectable(node_id):
		return
	_start_battle(node_id)


func _on_party_requested() -> void:
	map_view.hide()
	party_view.show()


func _on_party_closed() -> void:
	party_view.hide()
	map_view.show()


func _start_battle(node_id: int) -> void:
	_battle = BattleScene.instantiate()
	# 장비를 바꿨을 수 있으니 아군은 전투 직전의 파티 상태로 만든다.
	_battle.encounter = run_state.encounter_for(node_id, party.build_battle_roster())
	_battle.battle_finished.connect(_on_battle_finished.bind(node_id))
	_battle.battle_fled.connect(_on_battle_fled)
	map_view.hide_result()
	map_view.hide()
	add_child(_battle)


## 도망쳤다: 보상도 진행도 변화도 없이 지도로 돌아온다 (패배와 달리 "졌다" 가 아니다).
func _on_battle_fled() -> void:
	if _battle == null:
		return
	_battle.queue_free()
	_battle = null
	map_view.show_result(FLED_TEXT)
	map_view.sync_from_state(run_state)
	map_view.show()


func _on_battle_finished(ally_won: bool, node_id: int) -> void:
	if _battle == null:
		return
	_battle.queue_free()
	_battle = null

	var previous_graph: MapGraph = run_state.graph
	if ally_won:
		var was_boss: bool = node_id == run_state.graph.boss_id
		run_state.resolve_win(node_id)
		var loot: ItemData = ItemPool.roll(_rng, _item_pool)
		party.add_item(loot)
		map_view.show_result(_victory_text(was_boss, loot))
	else:
		map_view.show_result(DEFEATED_TEXT)

	# 보스를 깨면 run_state 가 새 그래프를 만든다 — 화면도 그 그래프로 다시 짜야 한다.
	if run_state.graph != previous_graph:
		map_view.rebuild(run_state.graph)
	map_view.sync_from_state(run_state)
	map_view.show()


func _victory_text(was_boss: bool, loot: ItemData) -> String:
	var text: String = BOSS_CLEARED_TEXT if was_boss else "승리!"
	if loot != null:
		text += "\n획득: %s" % loot.display_name
	return text
