## 메인 씬의 뿌리. 지도 화면, 파티 화면, 전투 씬을 오가게 연결하고
## 진행 상태(MapRunState)와 파티(PartyState)를 게임 내내 들고 있는다.
class_name GameRoot
# Node: 화면에 직접 그리지 않고 자식 화면들만 관리한다.
extends Node

## 전투마다 새로 만드는 전투 씬.
const BattleScene: PackedScene = preload("res://Scenes/battle_3d.tscn")
## 보스를 깼을 때 지도에 띄우는 문구.
const BOSS_CLEARED_TEXT: String = "챕터 클리어! 새 지도를 펼칩니다"
## 졌을 때 지도에 띄우는 문구.
const DEFEATED_TEXT: String = "패배... 파티를 정비하고 다시 도전하세요"
## 도망쳤을 때 지도에 띄우는 문구.
const FLED_TEXT: String = "전투에서 도망쳤습니다"
## 시작할 때 가방에 넣어 주는 아이템 수.
const STARTING_ITEM_COUNT: int = 3

## 지도 진행 상태 (지금 지도, 깬 노드).
var run_state: MapRunState
## 파티·가방·장착 상태.
var party: PartyState
## 지도 화면.
var map_view: MapView
## 캐릭터 정보·인벤토리 화면.
var party_view: PartyView
## 게임 전체가 함께 쓰는 난수 생성기.
var _rng: RandomNumberGenerator
## 보상으로 뽑을 수 있는 아이템 전부.
var _item_pool: Array[ItemData] = []
## 진행 중인 전투 씬. 전투 중이 아니면 null.
var _battle: BattleRoot


## 상태를 만들고 지도·파티 화면을 붙인다.
func _ready() -> void:
	# 난수 생성기를 만든다.
	_rng = RandomNumberGenerator.new()
	# 실행할 때마다 다른 시드로 시작한다.
	_rng.randomize()
	# 첫 지도와 진행 상태를 만든다.
	run_state = MapRunState.new(_rng)

	# 시작 파티를 만든다.
	party = PartyState.new(EncounterGenerator.build_ally_roster(_rng))
	# 보상 아이템 목록을 불러온다.
	_item_pool = ItemPool.load_all()
	# 시작 아이템을 가방에 넣는다.
	for i in STARTING_ITEM_COUNT:
		party.add_item(ItemPool.roll(_rng, _item_pool))

	# 지도 화면을 만든다.
	map_view = MapView.new(run_state.graph)
	# 붙인다.
	add_child(map_view)
	# 노드를 누르면 전투를 시작한다.
	map_view.node_selected.connect(_on_node_selected)
	# 파티 버튼을 누르면 파티 화면을 연다.
	map_view.party_requested.connect(_on_party_requested)
	# 노드 색(잠김·열림·깸)을 진행 상태에 맞춘다.
	map_view.sync_from_state(run_state)

	# 지도 위에 겹쳐 그려지도록 지도보다 나중에 붙인다.
	party_view = PartyView.new()
	# 처음에는 숨긴다.
	party_view.hide()
	# 붙인다.
	add_child(party_view)
	# 파티 상태와 연결한다.
	party_view.bind(party)
	# 닫기를 누르면 지도로 돌아간다.
	party_view.closed.connect(_on_party_closed)


## 지도에서 노드를 눌렀다.
func _on_node_selected(node_id: int) -> void:
	# 이미 전투 중이거나 들어갈 수 없는 노드면 무시한다.
	if _battle != null or not run_state.is_selectable(node_id):
		return
	# 전투를 시작한다.
	_start_battle(node_id)


## 지도에서 파티 버튼을 눌렀다.
func _on_party_requested() -> void:
	# 지도를 숨긴다.
	map_view.hide()
	# 파티 화면을 보인다.
	party_view.show()


## 파티 화면에서 닫기를 눌렀다.
func _on_party_closed() -> void:
	# 파티 화면을 숨긴다.
	party_view.hide()
	# 지도를 다시 보인다.
	map_view.show()


## 그 노드의 전투 씬을 만들어 띄운다.
func _start_battle(node_id: int) -> void:
	# 전투 씬을 만든다.
	_battle = BattleScene.instantiate()
	# 장비를 바꿨을 수 있으니 아군은 전투 직전의 파티 상태로 만든다.
	_battle.encounter = run_state.encounter_for(node_id, party.build_battle_roster())
	# 전투가 끝나면 결과를 처리한다 (어느 노드였는지 함께 넘긴다).
	_battle.battle_finished.connect(_on_battle_finished.bind(node_id))
	# 도망치면 지도로 돌아간다.
	_battle.battle_fled.connect(_on_battle_fled)
	# 지난 결과 문구를 지운다.
	map_view.hide_result()
	# 지도를 숨긴다.
	map_view.hide()
	# 전투 씬을 붙인다.
	add_child(_battle)


## 도망쳤다: 보상도 진행도 변화도 없이 지도로 돌아온다 (패배와 달리 "졌다" 가 아니다).
func _on_battle_fled() -> void:
	# 전투 중이 아니면 무시한다 (중복 신호 방어).
	if _battle == null:
		return
	# 전투 씬을 지운다.
	_battle.queue_free()
	# 전투 중이 아니라고 표시한다.
	_battle = null
	# 도망 문구를 띄운다.
	map_view.show_result(FLED_TEXT)
	# 노드 색을 맞춘다.
	map_view.sync_from_state(run_state)
	# 지도를 보인다.
	map_view.show()


## 전투가 끝났다. 이겼으면 진행도와 보상을 반영하고 지도로 돌아온다.
func _on_battle_finished(ally_won: bool, node_id: int) -> void:
	# 전투 중이 아니면 무시한다 (중복 신호 방어).
	if _battle == null:
		return
	# 전투 씬을 지운다.
	_battle.queue_free()
	# 전투 중이 아니라고 표시한다.
	_battle = null

	# 결과 반영 전의 지도. 보스를 깨서 지도가 바뀌었는지 비교하는 데 쓴다.
	var previous_graph: MapGraph = run_state.graph
	# 이겼을 때.
	if ally_won:
		# 보스 노드였는지 미리 기억한다 (resolve_win 이 지도를 바꿀 수 있어서).
		var was_boss: bool = node_id == run_state.graph.boss_id
		# 진행도를 반영한다.
		run_state.resolve_win(node_id)
		# 보상 아이템을 하나 뽑는다.
		var loot: ItemData = ItemPool.roll(_rng, _item_pool)
		# 가방에 넣는다.
		party.add_item(loot)
		# 승리 문구를 띄운다.
		map_view.show_result(_victory_text(was_boss, loot))
	# 졌을 때.
	else:
		# 패배 문구를 띄운다 (진행도·파티는 그대로).
		map_view.show_result(DEFEATED_TEXT)

	# 보스를 깨면 run_state 가 새 그래프를 만든다 — 화면도 그 그래프로 다시 짜야 한다.
	if run_state.graph != previous_graph:
		map_view.rebuild(run_state.graph)
	# 노드 색을 맞춘다.
	map_view.sync_from_state(run_state)
	# 지도를 보인다.
	map_view.show()


## 승리 문구. 보스면 챕터 클리어 문구, 아니면 "승리!" 에 얻은 아이템 이름을 붙인다.
func _victory_text(was_boss: bool, loot: ItemData) -> String:
	# 첫 줄을 고른다.
	var text: String = BOSS_CLEARED_TEXT if was_boss else "승리!"
	# 얻은 아이템이 있으면 다음 줄에 붙인다.
	if loot != null:
		text += "\n획득: %s" % loot.display_name
	# 완성된 문구를 돌려준다.
	return text
