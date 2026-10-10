## 한 챕터의 지도 모양. 시작 → 이야기 노드들 → 보스로 이어지는 길과, 이야기 노드 옆의 파밍 노드를 만든다.
## 모양만 가진다 — 어디까지 깼는지는 MapRunState 가 관리한다.
class_name MapGraph
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 보스 앞까지 이어지는 본 이야기 노드 수.
const STORY_COUNT: int = 5
## 이야기 노드 하나에 매달리는 파밍 노드 수의 최솟값·최댓값. 2개면 양옆, 1개면 한쪽.
const FARM_MIN: int = 1
const FARM_MAX: int = 2

## 시작 노드 id. 가장 먼저 만들기 때문에 항상 0 이다.
var start_id: int = 0
## 보스 노드 id.
var boss_id: int
## 모든 노드. 배열 위치가 곧 노드 id 다.
var nodes: Array[MapNode] = []


## 시작 → 이야기 1 → … → 이야기 STORY_COUNT → 보스로 이어지는 일직선 길을 만들고,
## 이야기 노드마다 옆으로 파밍 노드를 매단다. 연결(connections)은 [다음 이야기 노드, 파밍 노드들...] 순서다.
func _init(rng: RandomNumberGenerator) -> void:
	# 시작 노드를 맨 위(행 -1) 가운데에 만든다.
	_add(-1, 0, MapNode.Kind.START)

	# 이야기 노드 id 를 차례로 모은다 (마지막에 보스도 붙인다).
	var story_ids: Array[int] = []
	# 이야기 노드마다 매단 파밍 노드 id 목록.
	var farm_ids: Array[Array] = []
	# 이야기 노드를 한 행씩 만든다.
	for row in range(STORY_COUNT):
		# 가운데 열에 이야기 노드를 만든다.
		var story_id: int = _add(row, 0, MapNode.Kind.STORY)
		# 길 순서대로 기억한다.
		story_ids.append(story_id)
		# 같은 행 옆에 파밍 노드를 매달고 그 id 들을 기억한다.
		farm_ids.append(_add_farms(rng, row, story_id))

	# 마지막 이야기 노드 다음 행에 보스를 만든다.
	boss_id = _add(STORY_COUNT, 0, MapNode.Kind.BOSS)
	# 보스도 길의 끝으로 이어 붙인다.
	story_ids.append(boss_id)

	# 시작 노드는 첫 이야기 노드로 이어진다.
	nodes[start_id].connections.append(story_ids[0])
	# 이야기 노드마다 연결을 채운다.
	for i in range(STORY_COUNT):
		# 지금 이야기 노드.
		var story: MapNode = nodes[story_ids[i]]
		# 다음 이야기 노드(마지막이면 보스)를 먼저 넣는다.
		story.connections.append(story_ids[i + 1])
		# 그 뒤에 매달린 파밍 노드들을 넣는다.
		for farm_id in farm_ids[i]:
			story.connections.append(farm_id)


## id 로 노드를 찾는다.
func get_node(id: int) -> MapNode:
	# 배열 위치가 곧 id 다.
	return nodes[id]


## 노드 개수.
func node_count() -> int:
	# 배열 길이를 돌려준다.
	return nodes.size()


## 노드를 하나 만들어 끝에 붙이고 그 id 를 돌려준다.
func _add(row: int, col: int, kind: MapNode.Kind, parent_id: int = -1) -> int:
	# 지금 배열 길이가 새 노드의 id 가 된다.
	var id: int = nodes.size()
	# 노드를 만들어 붙인다.
	nodes.append(MapNode.new(id, row, col, kind, parent_id))
	# 새 id 를 돌려준다.
	return id


## 이야기 노드 옆에 파밍 노드를 1~2 개 매달고 그 id 들을 돌려준다.
func _add_farms(rng: RandomNumberGenerator, row: int, story_id: int) -> Array[int]:
	# 만든 파밍 노드 id 목록.
	var ids: Array[int] = []
	# 몇 개를 매달지 뽑는다.
	var count: int = rng.randi_range(FARM_MIN, FARM_MAX)
	# 2 개면 양옆에 하나씩 둔다.
	if count >= 2:
		# 왼쪽 파밍 노드.
		ids.append(_add(row, -1, MapNode.Kind.FARM, story_id))
		# 오른쪽 파밍 노드.
		ids.append(_add(row, 1, MapNode.Kind.FARM, story_id))
	# 1 개면 왼쪽·오른쪽 중 한쪽에만 둔다.
	else:
		# 반반 확률로 방향을 고른다.
		var side: int = -1 if rng.randi_range(0, 1) == 0 else 1
		# 고른 쪽에 파밍 노드를 만든다.
		ids.append(_add(row, side, MapNode.Kind.FARM, story_id))
	# 만든 id 들을 돌려준다.
	return ids
