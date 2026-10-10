## 지도 진행 상태와 해금 규칙. 지금 지도(MapGraph), 어디까지 깼는지, 이야기·보스 노드의 고정 적 구성을 가진다.
## 노드에 의존하지 않아서 화면 없이 테스트할 수 있다.
class_name MapRunState
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 지금 챕터의 지도. 보스를 깨면 새 지도로 바뀐다.
var graph: MapGraph
## 지도 만들기와 적 뽑기에 쓰는 난수 생성기.
var rng: RandomNumberGenerator
## 가장 마지막으로 깬 이야기 노드(또는 시작). 파밍 노드를 깨도 바뀌지 않는다.
var current_node_id: int
## 깬 노드. 파밍 노드는 반복해서 들어갈 수 있으므로 여기에 넣지 않는다.
var cleared: Dictionary = {}
## 이야기·보스 노드의 적 구성. 같은 노드에 다시 도전해도 같은 적이 나온다.
var _story_enemies: Dictionary = {}


## 난수 생성기를 받아 첫 지도를 만든다.
func _init(p_rng: RandomNumberGenerator) -> void:
	# 난수 생성기를 기억한다.
	rng = p_rng
	# 지도와 진행 상태를 처음 상태로 만든다.
	reset()


## 지금 그 노드에 들어갈 수 있으면 true.
func is_selectable(node_id: int) -> bool:
	# 확인할 노드.
	var node: MapNode = graph.get_node(node_id)
	# 시작 노드는 전투가 없어서 고를 수 없다.
	if node.kind == MapNode.Kind.START:
		return false
	# 파밍 노드는 부모 이야기 노드를 깼으면 몇 번이든 들어갈 수 있다.
	if node.kind == MapNode.Kind.FARM:
		return cleared.has(node.parent_id)
	# 이미 깬 이야기·보스 노드는 다시 들어갈 수 없다.
	if cleared.has(node_id):
		return false
	# 그 외에는 마지막으로 깬 노드에서 바로 이어진 노드만 열린다.
	return graph.get_node(current_node_id).connections.has(node_id)


## 그 노드의 전투 구성. 이야기·보스는 처음 정해진 적이, 파밍은 들어갈 때마다 새로 뽑은 적이 나온다.
## 아군은 장비가 바뀔 수 있어서 호출하는 쪽(GameRoot)이 전투 직전에 넘긴다.
func encounter_for(node_id: int, ally_units: Array[UnitPlacement]) -> EncounterData:
	# 적 배치 목록.
	var enemies: Array[UnitPlacement]
	# 파밍 노드는 들어갈 때마다 일반 적을 새로 뽑는다.
	if graph.get_node(node_id).kind == MapNode.Kind.FARM:
		enemies = EncounterGenerator.build_enemy_placements(rng, false)
	# 이야기·보스 노드는 지도를 만들 때 정해 둔 적을 쓴다.
	else:
		enemies = _story_enemies[node_id]
	# 아군과 적을 묶어 전투 구성을 만든다.
	return EncounterGenerator.assemble_encounter(ally_units, enemies)


## 이겼을 때 호출한다. 이야기 노드면 진행도가 올라가고, 파밍 노드면 아무것도 바뀌지 않는다.
## 보스를 이기면 새 맵(다음 챕터)으로 넘어간다.
func resolve_win(node_id: int) -> void:
	# 들어갈 수 없는 노드였다면 무시한다 (잘못된 호출 방어).
	if not is_selectable(node_id):
		return
	# 파밍은 진행도에 영향이 없다.
	if graph.get_node(node_id).kind == MapNode.Kind.FARM:
		return
	# 이 노드까지 진행했다.
	current_node_id = node_id
	# 깬 노드로 기록한다.
	cleared[node_id] = true
	# 보스였다면 다음 챕터 지도로 넘어간다.
	if node_id == graph.boss_id:
		reset()


# 시드 있는 rng 를 계속 이어 쓴다 — 세션 전체가 하나의 시드로 재현 가능해야 한다.
func reset() -> void:
	# 새 지도를 만든다.
	graph = MapGraph.new(rng)
	# 시작 노드에서 출발한다.
	current_node_id = graph.start_id
	# 시작 노드는 처음부터 깬 것으로 친다.
	cleared = {graph.start_id: true}

	# 고정 적 구성을 새로 정한다.
	_story_enemies = {}
	# 모든 노드를 훑는다.
	for node in graph.nodes:
		# 이야기·보스 노드만 적을 미리 정해 둔다 (보스 노드는 보스 적으로).
		if node.kind == MapNode.Kind.STORY or node.kind == MapNode.Kind.BOSS:
			_story_enemies[node.id] = EncounterGenerator.build_enemy_placements(rng, node.is_boss)
