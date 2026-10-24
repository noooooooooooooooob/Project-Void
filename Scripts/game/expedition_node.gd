## 원정 지도의 노드 하나. id 는 Expedition.nodes 안의 번호와 같다.
class_name ExpeditionNode
extends RefCounted

var id: int
## 열 (0 = 왼쪽 끝, 출구는 마지막 열 다음).
var col: int
## 줄 (0 ~ Expedition.LANES - 1).
var lane: int
## ChapterData 의 노드 종류 (BATTLE, EVENT, ...).
var type: String
## 이어진 다음 열 노드 id.
var next: Array[int] = []
## 구역 출구인지.
var exit: bool = false
## 전투류 노드의 적 id 들.
var enemies: Array[String] = []
## 사건 노드의 대본 id (Resources/story/events/<id>.txt).
var event: String = ""


func _init(p_id: int, p_col: int, p_lane: int, p_type: String) -> void:
	id = p_id
	col = p_col
	lane = p_lane
	type = p_type


## 지도 밖에서 쓰는 전투 노드 (도구·테스트용, id = -1).
static func battle(p_type: String, enemy_ids: Array[String]) -> ExpeditionNode:
	var n := ExpeditionNode.new(-1, 0, 0, p_type)
	n.enemies = enemy_ids
	return n


func is_battle() -> bool:
	return type == ChapterData.BATTLE or type == ChapterData.ELITE or type == ChapterData.BOSS
