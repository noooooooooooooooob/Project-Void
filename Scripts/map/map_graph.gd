class_name MapGraph
extends RefCounted

const BRANCH_COUNT: int = 2
const STEPS_PER_BRANCH: int = 4

var start_id: int = 0
var boss_id: int
var nodes: Array[MapNode] = []


func _init() -> void:
	boss_id = BRANCH_COUNT * STEPS_PER_BRANCH + 1

	var start := MapNode.new(start_id, -1, -1, false)
	nodes.append(start)

	for branch in BRANCH_COUNT:
		var previous: MapNode = start
		for step in STEPS_PER_BRANCH:
			var id: int = 1 + branch * STEPS_PER_BRANCH + step
			var node := MapNode.new(id, branch, step, false)
			previous.connections.append(id)
			nodes.append(node)
			previous = node
		previous.connections.append(boss_id)

	nodes.append(MapNode.new(boss_id, -1, -1, true))


func get_node(id: int) -> MapNode:
	return nodes[id]


func node_count() -> int:
	return nodes.size()
