## 상점 노드 하나의 진열.
class_name ShopStock
extends RefCounted


class ItemOffer:
	var item: ItemData
	var price: int

	func _init(p_item: ItemData, p_price: int) -> void:
		item = p_item
		price = p_price


var items: Array[ItemOffer] = []
var cards: Array[CardOffer] = []
var heal_price: int = 0
