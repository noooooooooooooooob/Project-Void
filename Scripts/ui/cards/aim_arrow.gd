class_name AimArrow
extends Control

const COLOR := Color(1.0, 1.0, 1.0, 0.9)
const WIDTH: float = 6.0
const HEAD_SIZE: float = 18.0
const SEGMENTS: int = 20
const ARC_HEIGHT: float = 120.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_aim(from_global: Vector2, to_global: Vector2) -> void:
	_from = from_global - global_position
	_to = to_global - global_position
	visible = true
	queue_redraw()


func hide_aim() -> void:
	visible = false


func is_aiming() -> bool:
	return visible


func _draw() -> void:
	var control_point := Vector2((_from.x + _to.x) / 2.0, minf(_from.y, _to.y) - ARC_HEIGHT)
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		var t: float = float(i) / SEGMENTS
		points.append(_from.lerp(control_point, t).lerp(control_point.lerp(_to, t), t))
	draw_polyline(points, COLOR, WIDTH, true)
	var direction: Vector2 = (points[SEGMENTS] - points[SEGMENTS - 1]).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var base: Vector2 = _to - direction * HEAD_SIZE
	draw_colored_polygon(PackedVector2Array([_to, base + normal * HEAD_SIZE * 0.6, base - normal * HEAD_SIZE * 0.6]), COLOR)
