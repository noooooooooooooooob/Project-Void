# @tool: 에디터 플러그인.
@tool
## 카드 범위(area) 인스펙터 편집기를 등록한다.
extends EditorPlugin

# 인스펙터 플러그인.
const AreaInspectorPlugin := preload("res://addons/card_area_editor/area_inspector_plugin.gd")

## 등록한 인스펙터 플러그인.
var _inspector: EditorInspectorPlugin


## 켜질 때 등록.
func _enter_tree() -> void:
	# 만들어서 등록한다.
	_inspector = AreaInspectorPlugin.new()
	add_inspector_plugin(_inspector)


## 꺼질 때 해제.
func _exit_tree() -> void:
	# 등록을 푼다.
	remove_inspector_plugin(_inspector)
