class_name MapGraph
extends RefCounted

## 시작과 보스 사이에 놓인 전투 층 수.
const ROWS: int = 6
## 한 층의 통로(칸) 수 — 노드의 col 은 0..COLS-1.
const COLS: int = 6
## 시작에서 보스까지 잇는 무작위 경로 수. 경로들이 같은 칸을 지나면 자연히 합쳐지고,
## 다른 칸으로 흩어지면 갈라진다.
const PATH_COUNT: int = 6
## 시작이 최소 이만큼은 서로 다른 칸으로 갈라지도록 강제한다.
const MIN_START_BRANCHES: int = 3

var start_id: int = 0
var boss_id: int
var nodes: Array[MapNode] = []

## (row, col) -> node id. 같은 칸을 여러 경로가 지나면 노드를 하나만 만들어 합류시킨다.
var _cell_id: Dictionary = {}


func _init(rng: RandomNumberGenerator) -> void:
	nodes.append(MapNode.new(start_id, -1, COLS / 2, false))
	_generate(rng)
	boss_id = nodes.size()
	nodes.append(MapNode.new(boss_id, ROWS, COLS / 2, true))
	_connect_last_row_to_boss()


func get_node(id: int) -> MapNode:
	return nodes[id]


func node_count() -> int:
	return nodes.size()


func _generate(rng: RandomNumberGenerator) -> void:
	var start_cols: Array[int] = _spread_start_columns(rng)
	for path in range(PATH_COUNT):
		var col: int = start_cols[path] if path < start_cols.size() else rng.randi_range(0, COLS - 1)
		var previous_id: int = start_id
		for row in range(ROWS):
			var node_id: int = _node_at(row, col)
			if not nodes[previous_id].connections.has(node_id):
				nodes[previous_id].connections.append(node_id)
			previous_id = node_id
			col = clampi(col + rng.randi_range(-1, 1), 0, COLS - 1)


func _node_at(row: int, col: int) -> int:
	var key := Vector2i(row, col)
	if _cell_id.has(key):
		return _cell_id[key]
	var id: int = nodes.size()
	nodes.append(MapNode.new(id, row, col, false))
	_cell_id[key] = id
	return id


func _spread_start_columns(rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for col in range(COLS):
		pool.append(col)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var picked: Array[int] = []
	for i in range(mini(MIN_START_BRANCHES, pool.size())):
		picked.append(pool[i])
	return picked


func _connect_last_row_to_boss() -> void:
	for node in nodes:
		if node.row == ROWS - 1 and not node.connections.has(boss_id):
			node.connections.append(boss_id)
