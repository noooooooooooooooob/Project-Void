## 파티원 한 명에게 줄 수 있는 카드 한 장 (전투 보상·상점 진열). 상점이 아니면 price 는 0.
class_name CardOffer
extends RefCounted

## 파티원 번호.
var member: int
var card: CardData
var price: int = 0


func _init(p_member: int, p_card: CardData, p_price: int = 0) -> void:
	member = p_member
	card = p_card
	price = p_price
