class_name MapRunState
extends RefCounted

var graph: MapGraph
var rng: RandomNumberGenerator
var current_node_id: int
var cleared: Dictionary = {}
var _encounters: Dictionary = {}


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	reset()


func is_selectable(node_id: int) -> bool:
	if cleared.has(node_id):
		return false
	return graph.get_node(current_node_id).connections.has(node_id)


func encounter_for(node_id: int) -> EncounterData:
	return _encounters[node_id]


func resolve_win(node_id: int) -> void:
	if not is_selectable(node_id):
		return
	current_node_id = node_id
	cleared[node_id] = true
	if node_id == graph.boss_id:
		reset()


# 시드 있는 rng 를 계속 이어 쓴다 — 패배해도 세션 전체가 하나의 시드로 재현 가능해야 한다.
func reset() -> void:
	graph = MapGraph.new()
	current_node_id = graph.start_id
	cleared = {graph.start_id: true}

	var ally_units: Array[UnitPlacement] = EncounterGenerator.build_ally_roster(rng)
	_encounters = {}
	for node in graph.nodes:
		if node.id == graph.start_id:
			continue
		_encounters[node.id] = EncounterGenerator.build_encounter(rng, ally_units, node.is_boss)
