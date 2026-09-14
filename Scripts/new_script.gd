# Godot 가 새 스크립트를 만들 때 넣어 주는 기본 템플릿이다.
# 게임에서는 쓰지 않는다 (어떤 씬에도 붙어 있지 않음).
# Node 를 상속하므로 씬 트리에 붙일 수 있는 노드 스크립트다.
extends Node


# Called when the node enters the scene tree for the first time.
# (노드가 씬 트리에 처음 들어올 때 한 번 불린다.)
func _ready() -> void:
	# 아직 할 일이 없으므로 비워 둔다.
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
# (매 프레임 불린다. delta 는 이전 프레임부터 지난 초 단위 시간이다.)
func _process(delta: float) -> void:
	# 아직 할 일이 없으므로 비워 둔다.
	pass
