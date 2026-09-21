## 런 하나의 진행 상황. 맵 생김새(MapGraph) 위에 "지금 어디에 서 있고 어디를 깼는지"와
## 점마다 미리 뽑아 둔 전투 구성을 얹어 들고 있다.
## 전투 구성은 그 점에 들어갈 때가 아니라 런을 짤 때 미리 뽑는다 — 맵을 보는 동안 적 구성이 흔들리지 않는다.
class_name MapRunState
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 이번 런의 맵 생김새.
var graph: MapGraph
## 맵과 전투 구성을 뽑는 데 쓰는 난수기.
var rng: RandomNumberGenerator
## 지금 서 있는 점의 번호.
var current_node_id: int
## 이미 깬 점들. 번호를 열쇠로만 쓰는 집합 대용이라 값은 언제나 true 다.
var cleared: Dictionary = {}
## 점 번호 → 그 점에서 치를 전투 구성.
var _encounters: Dictionary = {}


## 난수기를 받아 첫 런을 짠다.
func _init(p_rng: RandomNumberGenerator) -> void:
	# 난수기를 기억한다 (reset 이 계속 쓴다).
	rng = p_rng
	# 맵과 전투 구성을 처음 만든다.
	reset()


## 지금 자리에서 그 점으로 갈 수 있는지.
func is_selectable(node_id: int) -> bool:
	# 이미 깬 점은 되돌아갈 수 없다.
	if cleared.has(node_id):
		return false
	# 지금 서 있는 점에서 이어진 길이 있어야 갈 수 있다.
	return graph.get_node(current_node_id).connections.has(node_id)


## 그 점에서 치를 전투 구성을 꺼낸다.
func encounter_for(node_id: int) -> EncounterData:
	# 런을 짤 때 미리 뽑아 둔 것을 그대로 준다.
	return _encounters[node_id]


## 그 점의 전투를 이겼을 때 진행을 옮긴다.
func resolve_win(node_id: int) -> void:
	# 갈 수 없는 점이면 아무 일도 하지 않는다.
	if not is_selectable(node_id):
		return
	# 그 점으로 옮겨 선다.
	current_node_id = node_id
	# 깬 점으로 표시한다.
	cleared[node_id] = true
	# 보스를 깼으면 런이 끝난 것이므로 새 런을 짠다.
	if node_id == graph.boss_id:
		reset()


# 시드 있는 rng 를 계속 이어 쓴다 — 패배해도 세션 전체가 하나의 시드로 재현 가능해야 한다.
## 맵과 전투 구성을 새로 짠다. 런을 시작할 때, 보스를 깼을 때, 패배했을 때 부른다.
func reset() -> void:
	# 맵을 새로 만든다.
	graph = MapGraph.new()
	# 시작점에 선다.
	current_node_id = graph.start_id
	# 시작점은 싸울 일이 없으므로 처음부터 깬 것으로 둔다.
	cleared = {graph.start_id: true}

	# 아군 편성은 런 내내 그대로 쓰므로 한 번만 뽑아 모든 전투가 같은 것을 나눠 쓴다.
	var ally_units: Array[UnitPlacement] = EncounterGenerator.build_ally_roster(rng)
	# 지난 런의 전투 구성을 버린다.
	_encounters = {}
	# 점마다 전투 구성을 미리 뽑아 둔다.
	for node in graph.nodes:
		# 시작점에는 전투가 없다.
		if node.id == graph.start_id:
			continue
		# 보스 점은 적 수가 다르므로 보스 여부를 넘긴다.
		_encounters[node.id] = EncounterGenerator.build_encounter(rng, ally_units, node.is_boss)
