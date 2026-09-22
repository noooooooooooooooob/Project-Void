class_name MapNode
extends RefCounted

var id: int
var row: int
var col: int
var is_boss: bool
var connections: Array[int] = []


func _init(p_id: int, p_row: int, p_col: int, p_is_boss: bool) -> void:
	id = p_id
	row = p_row
	col = p_col
	is_boss = p_is_boss
