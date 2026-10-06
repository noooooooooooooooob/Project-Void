# @tool: 에디터 인스펙터에서 편집할 수 있게 한다.
@tool
## 전투 방에 놓는 소품 하나. 유닛처럼 카메라를 향한 그림 판으로 서 있다.
class_name PropPlacement
# Resource: 방 리소스 안에 하위 리소스로 저장된다.
extends Resource

## 소품 그림.
@export var texture: Texture2D
## 바닥 위치 (y 는 무시한다, 월드 좌표).
@export var position: Vector3 = Vector3.ZERO
## 그림을 맞출 높이 (3D 단위). 폭은 그림 비율대로.
@export var height: float = 1.0
