class_name MapRunState
extends RefCounted

var graph: MapGraph
var rng: RandomNumberGenerator
## 가장 마지막으로 깬 이야기 노드(또는 시작). 파밍 노드를 깨도 바뀌지 않는다.
var current_node_id: int
## 깬 노드. 파밍 노드는 반복해서 들어갈 수 있으므로 여기에 넣지 않는다.
var cleared: Dictionary = {}
## 이야기·보스 노드의 적 구성. 같은 노드에 다시 도전해도 같은 적이 나온다.
var _story_enemies: Dictionary = {}


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	reset()


func is_selectable(node_id: int) -> bool:
	var node: MapNode = graph.get_node(node_id)
	if node.kind == MapNode.Kind.START:
		return false
	if node.kind == MapNode.Kind.FARM:
		return cleared.has(node.parent_id)
	if cleared.has(node_id):
		return false
	return graph.get_node(current_node_id).connections.has(node_id)


## 그 노드의 전투 구성. 이야기·보스는 처음 정해진 적이, 파밍은 들어갈 때마다 새로 뽑은 적이 나온다.
## 아군은 장비가 바뀔 수 있어서 호출하는 쪽(GameRoot)이 전투 직전에 넘긴다.
func encounter_for(node_id: int, ally_units: Array[UnitPlacement]) -> EncounterData:
	var enemies: Array[UnitPlacement]
	if graph.get_node(node_id).kind == MapNode.Kind.FARM:
		enemies = EncounterGenerator.build_enemy_placements(rng, false)
	else:
		enemies = _story_enemies[node_id]
	return EncounterGenerator.assemble_encounter(ally_units, enemies)


## 이겼을 때 호출한다. 이야기 노드면 진행도가 올라가고, 파밍 노드면 아무것도 바뀌지 않는다.
## 보스를 이기면 새 맵(다음 챕터)으로 넘어간다.
func resolve_win(node_id: int) -> void:
	if not is_selectable(node_id):
		return
	if graph.get_node(node_id).kind == MapNode.Kind.FARM:
		return
	current_node_id = node_id
	cleared[node_id] = true
	if node_id == graph.boss_id:
		reset()


# 시드 있는 rng 를 계속 이어 쓴다 — 세션 전체가 하나의 시드로 재현 가능해야 한다.
func reset() -> void:
	graph = MapGraph.new(rng)
	current_node_id = graph.start_id
	cleared = {graph.start_id: true}

	_story_enemies = {}
	for node in graph.nodes:
		if node.kind == MapNode.Kind.STORY or node.kind == MapNode.Kind.BOSS:
			_story_enemies[node.id] = EncounterGenerator.build_enemy_placements(rng, node.is_boss)
