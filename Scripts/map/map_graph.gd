class_name MapGraph
extends RefCounted

## 보스 앞까지 이어지는 본 이야기 노드 수.
const STORY_COUNT: int = 5
## 이야기 노드 하나에 매달리는 파밍 노드 수의 최솟값·최댓값. 2개면 양옆, 1개면 한쪽.
const FARM_MIN: int = 1
const FARM_MAX: int = 2

var start_id: int = 0
var boss_id: int
var nodes: Array[MapNode] = []


## 시작 → 이야기 1 → … → 이야기 STORY_COUNT → 보스로 이어지는 일직선 길을 만들고,
## 이야기 노드마다 옆으로 파밍 노드를 매단다. 연결(connections)은 [다음 이야기 노드, 파밍 노드들...] 순서다.
func _init(rng: RandomNumberGenerator) -> void:
	_add(-1, 0, MapNode.Kind.START)

	var story_ids: Array[int] = []
	var farm_ids: Array[Array] = []
	for row in range(STORY_COUNT):
		var story_id: int = _add(row, 0, MapNode.Kind.STORY)
		story_ids.append(story_id)
		farm_ids.append(_add_farms(rng, row, story_id))

	boss_id = _add(STORY_COUNT, 0, MapNode.Kind.BOSS)
	story_ids.append(boss_id)

	nodes[start_id].connections.append(story_ids[0])
	for i in range(STORY_COUNT):
		var story: MapNode = nodes[story_ids[i]]
		story.connections.append(story_ids[i + 1])
		for farm_id in farm_ids[i]:
			story.connections.append(farm_id)


func get_node(id: int) -> MapNode:
	return nodes[id]


func node_count() -> int:
	return nodes.size()


func _add(row: int, col: int, kind: MapNode.Kind, parent_id: int = -1) -> int:
	var id: int = nodes.size()
	nodes.append(MapNode.new(id, row, col, kind, parent_id))
	return id


func _add_farms(rng: RandomNumberGenerator, row: int, story_id: int) -> Array[int]:
	var ids: Array[int] = []
	var count: int = rng.randi_range(FARM_MIN, FARM_MAX)
	if count >= 2:
		ids.append(_add(row, -1, MapNode.Kind.FARM, story_id))
		ids.append(_add(row, 1, MapNode.Kind.FARM, story_id))
	else:
		var side: int = -1 if rng.randi_range(0, 1) == 0 else 1
		ids.append(_add(row, side, MapNode.Kind.FARM, story_id))
	return ids
