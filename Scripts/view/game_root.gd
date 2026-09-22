class_name GameRoot
extends Node

const BattleScene: PackedScene = preload("res://Scenes/battle_3d.tscn")
const BOSS_CLEARED_TEXT: String = "런 클리어! 새 런을 시작합니다"
const DEFEATED_TEXT: String = "패배... 런을 초기화합니다"

var run_state: MapRunState
var map_view: MapView
var _battle: BattleRoot


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run_state = MapRunState.new(rng)

	map_view = MapView.new(run_state.graph)
	add_child(map_view)
	map_view.node_selected.connect(_on_node_selected)
	map_view.sync_from_state(run_state)


func _on_node_selected(node_id: int) -> void:
	if _battle != null or not run_state.is_selectable(node_id):
		return
	_start_battle(node_id)


func _start_battle(node_id: int) -> void:
	_battle = BattleScene.instantiate()
	_battle.encounter = run_state.encounter_for(node_id)
	_battle.battle_finished.connect(_on_battle_finished.bind(node_id))
	map_view.hide()
	add_child(_battle)


func _on_battle_finished(ally_won: bool, node_id: int) -> void:
	_battle.queue_free()
	_battle = null

	var previous_graph: MapGraph = run_state.graph
	if ally_won:
		var was_boss: bool = node_id == run_state.graph.boss_id
		run_state.resolve_win(node_id)
		if was_boss:
			map_view.show_result(BOSS_CLEARED_TEXT)
		else:
			map_view.hide_result()
	else:
		run_state.reset()
		map_view.show_result(DEFEATED_TEXT)

	# 보스 클리어나 패배로 런이 새로 시작되면 run_state 는 새 그래프를 만든다 — 화면도 그 그래프로 다시 짜야 한다.
	if run_state.graph != previous_graph:
		map_view.rebuild(run_state.graph)
	map_view.sync_from_state(run_state)
	map_view.show()
