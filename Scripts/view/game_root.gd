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
## 의뢰 중 빈 칸(이벤트·상점·휴식)에 들어갔을 때 띄우는 문구.
const EMPTY_ROOM_TEXT: String = "아무 일도 없었다"
## 의뢰 중 일반 전투에서 이겼을 때 첫 줄.
const BATTLE_WON_TEXT: String = "승리!"
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
## 의뢰 화면. 의뢰 중이 아니면 null.
var stage_view: StageView
## 진행 중인 의뢰. 의뢰 중이 아니면 null.
var _commission: CommissionRun
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


## 지도에서 노드를 눌렀다: 그 노드의 의뢰를 시작한다.
func _on_node_selected(node_id: int) -> void:
	# 이미 전투·의뢰 중이거나 들어갈 수 없는 노드면 무시한다.
	if _battle != null or _commission != null or not run_state.is_selectable(node_id):
		return
	# 체력이 가득 찬 새 의뢰를 만든다.
	_commission = CommissionRun.new(_rng, node_id, _member_max_hp())
	# 의뢰 화면을 만든다.
	stage_view = StageView.new(_commission)
	# 붙인다.
	add_child(stage_view)
	# 칸을 누르면 그 칸으로 간다.
	stage_view.node_selected.connect(_on_stage_node_selected)
	# 칸 색과 체력 줄을 맞춘다.
	stage_view.sync_from_run(_commission, party)
	# 지난 결과 문구를 지운다.
	map_view.hide_result()
	# 지도를 숨긴다.
	map_view.hide()


## 파티원별 최대 체력 (장비 반영).
func _member_max_hp() -> Array[int]:
	# 모을 목록.
	var result: Array[int] = []
	# 파티원마다.
	for i in party.member_count():
		result.append(party.stats(i)["max_hp"])
	# 돌려준다.
	return result


## 의뢰 화면에서 칸을 눌렀다: 이동하고, 전투·보스면 전투를 연다.
func _on_stage_node_selected(id: int) -> void:
	# 전투 중이거나 갈 수 없으면 무시한다.
	if _battle != null or _commission == null or not _commission.enter(id):
		return
	# 들어간 칸의 종류.
	var kind: StageNode.Kind = _commission.current_kind()
	# 빈 칸: 문구만 띄운다.
	if kind != StageNode.Kind.BATTLE and kind != StageNode.Kind.BOSS:
		stage_view.show_result(EMPTY_ROOM_TEXT)
		stage_view.sync_from_run(_commission, party)
		return
	# 아군: 장비 반영 배치에서 쓰러진 파티원을 빼고 지금 체력을 싣는다.
	var allies: Array[UnitPlacement] = _commission.battle_roster(party.build_battle_roster())
	# 보스는 그 월드맵 노드의 적, 일반 전투는 새로 뽑은 적.
	var encounter: EncounterData
	if kind == StageNode.Kind.BOSS:
		encounter = run_state.encounter_for(_commission.map_node_id, allies)
	else:
		encounter = EncounterGenerator.assemble_encounter(allies, EncounterGenerator.build_enemy_placements(_rng, false))
	# 전투를 연다.
	_start_battle(encounter)


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


## 전투 씬을 만들어 띄운다.
func _start_battle(encounter: EncounterData) -> void:
	# 전투 씬을 만든다.
	_battle = BattleScene.instantiate()
	# 전투 구성.
	_battle.encounter = encounter
	# 전투가 끝나면 결과를 처리한다.
	_battle.battle_finished.connect(_on_battle_finished)
	# 도망치면 의뢰 실패.
	_battle.battle_fled.connect(_on_battle_fled)
	# 지난 결과 문구를 지운다.
	stage_view.hide_result()
	# 의뢰 화면을 숨긴다.
	stage_view.hide()
	# 전투 씬을 붙인다.
	add_child(_battle)


## 도망쳤다: 의뢰 실패, 진행도 변화 없이 지도로 돌아온다.
func _on_battle_fled() -> void:
	# 전투 중이 아니면 무시한다 (중복 신호 방어).
	if _battle == null:
		return
	# 전투 씬을 지운다.
	_battle.queue_free()
	# 전투 중이 아니라고 표시한다.
	_battle = null
	# 의뢰 실패.
	_commission.fail()
	# 지도로.
	_return_to_map(FLED_TEXT)


## 전투가 끝났다. 체력을 넘기고, 이겼으면 보상을 주고, 의뢰 결과에 따라 의뢰 화면이나 지도로 간다.
func _on_battle_finished(ally_won: bool) -> void:
	# 전투 중이 아니면 무시한다 (중복 신호 방어).
	if _battle == null:
		return
	# 씬을 지우기 전에 아군 체력을 의뢰로 넘긴다.
	_commission.apply_battle_hp(_battle.ally_final_hp())
	# 전투 씬을 지운다.
	_battle.queue_free()
	# 전투 중이 아니라고 표시한다.
	_battle = null
	# 의뢰에 결과를 반영한다.
	_commission.finish_battle(ally_won)
	# 얻은 아이템 (지면 없음).
	var loot: ItemData = null
	# 이겼으면 보상 아이템을 하나 뽑아 가방에 넣는다.
	if ally_won:
		loot = ItemPool.roll(_rng, _item_pool)
		party.add_item(loot)
	# 의뢰 결과별.
	match _commission.state:
		# 보스까지 이겼다: 월드맵 노드를 깬다.
		CommissionRun.State.SUCCEEDED:
			# 보스 노드였는지 미리 기억한다 (resolve_win 이 지도를 바꿀 수 있어서).
			var was_boss: bool = _commission.map_node_id == run_state.graph.boss_id
			# 진행도를 반영한다.
			run_state.resolve_win(_commission.map_node_id)
			# 지도로.
			_return_to_map(_victory_text(was_boss, loot))
		# 졌다.
		CommissionRun.State.FAILED:
			_return_to_map(DEFEATED_TEXT)
		# 아직 의뢰 중: 의뢰 화면으로.
		_:
			# 승리 문구 (+ 획득 아이템).
			var text: String = BATTLE_WON_TEXT
			if loot != null:
				text += "\n획득: %s" % loot.display_name
			stage_view.show_result(text)
			# 칸 색과 체력 줄을 맞춘다.
			stage_view.sync_from_run(_commission, party)
			# 의뢰 화면을 보인다.
			stage_view.show()


## 의뢰를 끝내고 지도로 돌아온다.
func _return_to_map(text: String) -> void:
	# 의뢰 화면을 지운다.
	stage_view.queue_free()
	# 의뢰 중이 아니라고 표시한다 (체력은 다음 의뢰에서 새로 가득 찬다).
	stage_view = null
	_commission = null
	# 문구를 띄운다.
	map_view.show_result(text)
	# 보스를 깨면 run_state 가 새 그래프를 만든다 — 바뀌었는지 따로 들고 다니지 않고 항상 다시 짠다 (버튼 몇 개라 비용이 작다).
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
