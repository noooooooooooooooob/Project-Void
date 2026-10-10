# @tool: 에디터에서 실행된다.
@tool
## CardData 의 area 속성을 5×5 격자 편집기로 바꿔 보여 준다.
extends EditorInspectorPlugin

# 격자 속성.
const AreaGridProperty := preload("res://addons/card_area_editor/area_grid_property.gd")


## CardData 만 다룬다.
func _can_handle(object: Object) -> bool:
	# 카드 데이터인지.
	return object is CardData


## area 속성이면 격자 편집기를 넣고 기본 편집기를 숨긴다.
func _parse_property(_object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	# area 가 아니면 기본 편집기.
	if name != "area":
		return false
	# 격자 편집기를 넣는다.
	add_property_editor(name, AreaGridProperty.new())
	# 기본 배열 편집기는 숨긴다.
	return true
