## 게임 전체의 루트 스크립트이자 메인 씬(game_root.tscn). 맵과 전투를 오가는 일만 맡는다.
## 맵에서 점을 고르면 전투 씬을 띄우고, 전투가 끝나면 그 결과를 진행 상황에 반영한 뒤 맵으로 돌아온다.
## 전투 규칙도 맵 규칙도 직접 다루지 않는다 — MapRunState 와 BattleRoot 에게 넘긴다.
class_name GameRoot
# Node: 화면에 직접 그리는 것이 없어 가장 가벼운 노드면 된다 (맵은 Control, 전투는 Node3D 라 부모는 둘 다 담을 수 있어야 한다).
extends Node

## 점을 고를 때마다 새로 띄울 전투 씬.
const BattleScene: PackedScene = preload("res://Scenes/battle_3d.tscn")
## 보스를 깨서 런이 끝났을 때 띄우는 문구.
const BOSS_CLEARED_TEXT: String = "런 클리어! 새 런을 시작합니다"
## 전투에서 져서 런이 되돌아갈 때 띄우는 문구.
const DEFEATED_TEXT: String = "패배... 런을 초기화합니다"

## 지금 런의 진행 상황 (맵 생김새와 전투 구성까지 들고 있다).
var run_state: MapRunState
## 맵 화면.
var map_view: MapView
## 지금 치르고 있는 전투. 맵을 보고 있는 동안에는 null 이다.
var _battle: BattleRoot


## 런을 시작하고 맵을 띄운다.
func _ready() -> void:
	# 런마다 다른 맵이 나오도록 시드를 무작위로 잡는다.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# 맵과 전투 구성을 짠다.
	run_state = MapRunState.new(rng)

	# 맵 화면을 만든다.
	map_view = MapView.new()
	# 붙이면 _ready 가 돌아 버튼이 만들어진다.
	add_child(map_view)
	# 점을 고르면 알림을 받는다.
	map_view.node_selected.connect(_on_node_selected)
	# 버튼 색과 활성 상태를 지금 진행 상황에 맞춘다.
	map_view.sync_from_state(run_state)


## 맵에서 점을 골랐을 때.
func _on_node_selected(node_id: int) -> void:
	# 이미 전투 중이거나 갈 수 없는 점이면 무시한다.
	if _battle != null or not run_state.is_selectable(node_id):
		return
	# 그 점의 전투를 띄운다.
	_start_battle(node_id)


## 그 점의 전투 씬을 띄우고 맵을 감춘다.
func _start_battle(node_id: int) -> void:
	# 전투 씬을 하나 만든다.
	_battle = BattleScene.instantiate()
	# 붙이기 전에 넣어야 전투의 _ready 가 이 구성으로 판을 짠다.
	_battle.encounter = run_state.encounter_for(node_id)
	# 끝났을 때 어느 점의 전투였는지 함께 알도록 번호를 미리 묶어 둔다.
	_battle.battle_finished.connect(_on_battle_finished.bind(node_id))
	# 전투 중에는 맵을 감춘다 (지우지 않으므로 버튼을 다시 만들 필요가 없다).
	map_view.hide()
	# 전투를 화면에 붙인다.
	add_child(_battle)


## 전투가 끝났을 때. 결과를 진행 상황에 반영하고 맵으로 돌아온다.
func _on_battle_finished(ally_won: bool, node_id: int) -> void:
	# 전투 씬을 치운다.
	_battle.queue_free()
	# 맵을 보는 중임을 표시한다 (_on_node_selected 가 이걸로 전투 중인지 본다).
	_battle = null

	# 이겼을 때.
	if ally_won:
		# resolve_win 이 보스를 깨면 런을 새로 짜 버리므로 그 전에 확인해 둔다.
		var was_boss: bool = node_id == run_state.graph.boss_id
		# 진행을 그 점으로 옮긴다.
		run_state.resolve_win(node_id)
		# 보스였으면 런이 끝났음을 알린다.
		if was_boss:
			map_view.show_result(BOSS_CLEARED_TEXT)
		# 보통 점이면 지난 런의 문구가 남아 있지 않게 지운다.
		else:
			map_view.hide_result()
	# 졌을 때.
	else:
		# 런을 처음부터 다시 짠다.
		run_state.reset()
		# 왜 맵이 처음으로 돌아갔는지 알린다.
		map_view.show_result(DEFEATED_TEXT)

	# 바뀐 진행 상황에 버튼을 맞춘다.
	map_view.sync_from_state(run_state)
	# 맵을 다시 보여 준다.
	map_view.show()
