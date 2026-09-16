class_name MapNode
extends RefCounted

var id: int
var branch: int
var step: int
var is_boss: bool
var connections: Array[int] = []


func _init(p_id: int, p_branch: int, p_step: int, p_is_boss: bool) -> void:
	id = p_id
	branch = p_branch
	step = p_step
	is_boss = p_is_boss
